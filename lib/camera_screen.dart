import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_screen.dart';
import 'gallery_screen.dart';
import 'about_screen.dart';
import 'stats_screen.dart';
import 'services/model_service.dart';

class CameraScreen extends StatefulWidget {
  final bool isActive;

  const CameraScreen({
    super.key,
    required this.isActive,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription> cameras = [];

  int selectedCameraIndex = 0;

  final ModelService _modelService = ModelService();
  CameraImage? _lastCameraImage;

  HandLandmarkerPlugin? handLandmarker;
  StreamSubscription<List<Hand>>? landmarkSubscription;

  bool isHandDetectionReady = false;
  bool autoDetectEnabled = true;
  bool isDetecting = false;
  bool isProcessingImage = false;

  bool isLandmarkFrameBusy = false;
  bool isWaitingForLandmarkResult = false;

  Timer? detectionTimer;

  int totalSignsRecognized = 0;
  int detectionCount = 0;

  String detectedSign = "Waiting...";
  String convertedText = "Waiting...";
  String confidence = "0%";
  String lastDetectedSign = "None";

  String recognizedText = "";

  List<String> history = [];

  List<String> capturedImages = [];
  String capturedImagePath = "";
  String capturedTime = "";

  final FlutterTts flutterTts = FlutterTts();

  double speechSpeed = 0.45;
  double speechPitch = 0.85;
  String selectedLanguage = "English";

  DateTime? lastRecognitionTime;
  DateTime? lastProcessedFrameTime;
  DateTime? lastSpokenTime;

  String? candidateSign;
  int candidateCount = 0;

  String? spokenSign;

  String currentHandStatus = "Searching for hand...";

  @override
  void initState() {
    super.initState();

    loadHistory();
    loadImages();
    loadVoiceSettings();
    loadStatistics();

    initializeModelService();
    initializeHandLandmarker();
    initializeCamera();
  }

  Future<void> initializeModelService() async {
    try {
      await _modelService.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("MODEL SERVICE INIT ERROR: $e");
    }
  }

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      if (autoDetectEnabled) {
        startAutomaticDetection();
      }
    }

    if (!widget.isActive && oldWidget.isActive) {
      stopAutomaticDetection();
      flutterTts.stop();

      candidateSign = null;
      candidateCount = 0;
      spokenSign = null;
      lastSpokenTime = null;

      isWaitingForLandmarkResult = false;
      isLandmarkFrameBusy = false;

      if (mounted) {
        setState(() {
          isDetecting = false;
        });
      }
    }
  }

  // ============================================================
  // HAND LANDMARKER
  // ============================================================

  Future<void> initializeHandLandmarker() async {
    try {
      handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.60,
        delegate: HandLandmarkerDelegate.cpu,
      );

      landmarkSubscription = handLandmarker!.landmarkStream.listen(
        handleLandmarks,
        onError: (error) {
          isWaitingForLandmarkResult = false;
          isLandmarkFrameBusy = false;

          debugPrint("HAND LANDMARK ERROR: $error");
        },
      );

      if (!mounted) return;

      setState(() {
        isHandDetectionReady = true;
      });

      debugPrint("SIGNSPEAK HAND LANDMARKER READY");
    } catch (e) {
      debugPrint("HAND LANDMARKER ERROR: $e");
    }
  }

  void processCameraImage(CameraImage image) {
    if (!isHandDetectionReady) return;
    if (handLandmarker == null) return;
    if (!widget.isActive) return;
    if (!autoDetectEnabled) return;
    if (controller == null) return;

    if (isWaitingForLandmarkResult) {
      return;
    }

    final now = DateTime.now();

    if (lastProcessedFrameTime != null &&
        now.difference(lastProcessedFrameTime!).inMilliseconds < 400) {
      return;
    }

    lastProcessedFrameTime = now;
    _lastCameraImage = image;

    isWaitingForLandmarkResult = true;
    isLandmarkFrameBusy = true;

    try {
      handLandmarker!.processFrame(
        image,
        controller!.description.sensorOrientation,
      );
    } catch (e) {
      debugPrint("FRAME PROCESSING ERROR: $e");

      isWaitingForLandmarkResult = false;
      isLandmarkFrameBusy = false;
    }
  }

  void handleLandmarks(List<Hand> hands) {
    isWaitingForLandmarkResult = false;
    isLandmarkFrameBusy = false;

    if (!mounted) return;

    // ------------------------------------------------------------
    // NO HAND
    // ------------------------------------------------------------

    if (hands.isEmpty) {
      candidateSign = null;
      candidateCount = 0;

      setState(() {
        currentHandStatus = "No hand detected";
        detectedSign = "No Hand Detected";
        confidence = "0%";
      });

      return;
    }

    // ------------------------------------------------------------
    // HAND FOUND: TFLite Inference via Hand Bounding Box
    // ------------------------------------------------------------

    final hand = hands.first;
    String sign = "Unknown";
    double score = 0.0;

    if (_modelService.isInitialized && _lastCameraImage != null) {
      final points = hand.landmarks;
      double minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
      for (final p in points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }

      final rawRect = NormalizedRect(
        left: minX,
        top: minY,
        right: maxX,
        bottom: maxY,
      );

      // Square crop with 35% padding around hand landmarks
      final squareCrop = rawRect.toSquareWithPadding(1.35);

      final isFront = controller != null &&
          controller!.description.lensDirection == CameraLensDirection.front;
      final orientation = controller?.description.sensorOrientation ?? 0;

      final inputTensor = _modelService.preprocessCameraImageFast(
        cameraImage: _lastCameraImage!,
        normalizedCrop: squareCrop,
        sensorOrientation: orientation,
        isFrontCamera: isFront,
      );

      final result = _modelService.runInference(inputTensor);

      if (result.isRecognized) {
        sign = result.label;
        score = result.confidence;
      } else {
        sign = "Unknown";
        score = result.confidence;
      }
    } else {
      // Fallback heuristic if model is still loading
      final heuristicResult = recognizeGesture(hand);
      if (heuristicResult != null) {
        sign = heuristicResult.$1;
        score = heuristicResult.$2;
      }
    }

    setState(() {
      currentHandStatus = "Hand detected";
      detectedSign = sign;
      confidence = "${(score * 100).toStringAsFixed(0)}%";
    });

    if (!autoDetectEnabled) return;
    if (!widget.isActive) return;

    if (sign == "Unknown" || sign == "No Hand Detected" || sign == "nothing") {
      candidateSign = null;
      candidateCount = 0;
      return;
    }

    // ------------------------------------------------------------
    // STABLE SIGN CHECK (Temporal smoothing)
    // ------------------------------------------------------------

    if (candidateSign == sign) {
      candidateCount++;
    } else {
      candidateSign = sign;
      candidateCount = 1;
    }

    debugPrint(
      "SIGN CANDIDATE: $sign | COUNT: $candidateCount/3 | CONFIDENCE: ${(score * 100).toStringAsFixed(1)}%",
    );

    if (candidateCount >= 3) {
      registerDetectedSign(sign, score);

      candidateCount = 0;
      candidateSign = null;
    }
  }

  // ============================================================
  // SIMPLE SIGN RECOGNITION
  // ============================================================

  (String, double)? recognizeGesture(Hand hand) {
    final points = hand.landmarks;

    if (points.length < 21) {
      return null;
    }

    final indexExtended = fingerExtended(
      points[8],
      points[6],
      points[5],
      points[0],
    );

    final middleExtended = fingerExtended(
      points[12],
      points[10],
      points[9],
      points[0],
    );

    final ringExtended = fingerExtended(
      points[16],
      points[14],
      points[13],
      points[0],
    );

    final pinkyExtended = fingerExtended(
      points[20],
      points[18],
      points[17],
      points[0],
    );

    final thumbExtended = thumbIsExtended(points);

    final extendedCount = [
      indexExtended,
      middleExtended,
      ringExtended,
      pinkyExtended,
    ].where((value) => value).length;

    // B
    if (indexExtended &&
        middleExtended &&
        ringExtended &&
        pinkyExtended &&
        !thumbExtended) {
      return ("B", 0.90);
    }

    // V
    if (indexExtended &&
        middleExtended &&
        !ringExtended &&
        !pinkyExtended) {
      final gap = distance(
        points[8],
        points[12],
      );

      if (gap > 0.10) {
        return ("V", 0.90);
      }
    }

    // L
    if (indexExtended &&
        thumbExtended &&
        !middleExtended &&
        !ringExtended &&
        !pinkyExtended) {
      return ("L", 0.88);
    }

    // I
    if (!indexExtended &&
        !middleExtended &&
        !ringExtended &&
        pinkyExtended) {
      return ("I", 0.86);
    }

    // D
    if (indexExtended &&
        !middleExtended &&
        !ringExtended &&
        !pinkyExtended) {
      return ("D", 0.84);
    }

    // A
    if (extendedCount == 0 && thumbExtended) {
      return ("A", 0.82);
    }

    // O
    if (isClosedShape(points)) {
  return ("O", 0.88);
}
    // Open hand
    if (extendedCount == 4 && thumbExtended) {
      return ("B", 0.75);
    }

    return null;
  }

  bool fingerExtended(
    Landmark tip,
    Landmark pip,
    Landmark mcp,
    Landmark wrist,
  ) {
    final tipDistance = distance(
      tip,
      wrist,
    );

    final pipDistance = distance(
      pip,
      wrist,
    );

    return tipDistance > pipDistance * 1.15;
  }

  bool thumbIsExtended(List<Landmark> points) {
    final thumbTip = points[4];
    final thumbIp = points[3];
    final wrist = points[0];

    final tipDistance = distance(
      thumbTip,
      wrist,
    );

    final ipDistance = distance(
      thumbIp,
      wrist,
    );

    return tipDistance > ipDistance * 1.12;
  }
bool isClosedShape(List<Landmark> points) {
  final thumbIndexGap =
      distance(points[4], points[8]);

  final indexExtended = fingerExtended(
    points[8],
    points[6],
    points[5],
    points[0],
  );

  final middleExtended = fingerExtended(
    points[12],
    points[10],
    points[9],
    points[0],
  );

  final ringExtended = fingerExtended(
    points[16],
    points[14],
    points[13],
    points[0],
  );

  final pinkyExtended = fingerExtended(
    points[20],
    points[18],
    points[17],
    points[0],
  );

  return thumbIndexGap < 0.16 &&
      !indexExtended &&
      !middleExtended &&
      !ringExtended &&
      !pinkyExtended;
}

  double distance(
    Landmark a,
    Landmark b,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt(
      dx * dx + dy * dy,
    );
  }

  // ============================================================
  // REGISTER DETECTION
  // ============================================================

  Future<void> registerDetectedSign(
    String sign,
    double score,
  ) async {
    final now = DateTime.now();

    if (lastSpokenTime != null) {
      final difference = now.difference(lastSpokenTime!);

      if (difference.inMilliseconds < 1800) {
        return;
      }
    }

    if (spokenSign == sign) {
      return;
    }

    spokenSign = sign;
    lastSpokenTime = now;
    lastRecognitionTime = now;

    totalSignsRecognized++;
    detectionCount++;

    recognizedText += sign;

    if (mounted) {
      setState(() {
        detectedSign = sign;
        convertedText = recognizedText;
        confidence =
            "${(score * 100).toStringAsFixed(0)}%";
        lastDetectedSign = sign;
      });
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      "totalSignsRecognized",
      totalSignsRecognized,
    );

    await prefs.setString(
      "lastDetectedSign",
      sign,
    );

    history.add(
      "$sign - ${DateTime.now()}",
    );

    await saveHistory();

    await speakRecognizedText(sign);

    Future.delayed(
      const Duration(milliseconds: 1000),
      () {
        if (!mounted) return;

        if (candidateSign != sign) {
          spokenSign = null;
        }
      },
    );
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint("NO CAMERA FOUND");
        return;
      }

      final frontIndex = cameras.indexWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.front,
      );

      selectedCameraIndex =
          frontIndex != -1 ? frontIndex : 0;

      await createCamera();
    } catch (e) {
      debugPrint(
        "CAMERA INITIALIZATION ERROR: $e",
      );
    }
  }

  Future<void> createCamera() async {
    try {
      await controller?.stopImageStream();
    } catch (_) {}

    await controller?.dispose();

    controller = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;

    setState(() {});

    try {
      await controller!.startImageStream(
        processCameraImage,
      );
    } catch (e) {
      debugPrint(
        "IMAGE STREAM ERROR: $e",
      );
    }

    if (!mounted) return;

    if (widget.isActive && autoDetectEnabled) {
      startAutomaticDetection();
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) return;

    stopAutomaticDetection();

    try {
      await controller?.stopImageStream();
    } catch (_) {}

    candidateSign = null;
    candidateCount = 0;
    spokenSign = null;
    lastProcessedFrameTime = null;
    isLandmarkFrameBusy = false;
    isWaitingForLandmarkResult = false;

    selectedCameraIndex =
        selectedCameraIndex == 0 ? 1 : 0;

    await createCamera();
  }

  // ============================================================
  // AUTOMATIC DETECTION
  // ============================================================

  void startAutomaticDetection() {
    if (!widget.isActive) return;
    if (!autoDetectEnabled) return;

    detectionTimer?.cancel();

    detectionTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) {
        if (!mounted) return;

        setState(() {
          isDetecting = true;
        });

        Future.delayed(
          const Duration(milliseconds: 500),
          () {
            if (!mounted) return;

            setState(() {
              isDetecting = false;
            });
          },
        );
      },
    );

    debugPrint(
      "AUTOMATIC HAND DETECTION STARTED",
    );
  }

  void stopAutomaticDetection() {
    detectionTimer?.cancel();
    detectionTimer = null;

    candidateSign = null;
    candidateCount = 0;

    isWaitingForLandmarkResult = false;
    isLandmarkFrameBusy = false;

    if (mounted) {
      setState(() {
        isDetecting = false;
      });
    }

    debugPrint(
      "AUTOMATIC HAND DETECTION STOPPED",
    );
  }

  // ============================================================
  // VOICE
  // ============================================================

  Future<void> loadVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      speechSpeed =
          prefs.getDouble("speechSpeed") ?? 0.45;

      speechPitch =
          prefs.getDouble("speechPitch") ?? 0.85;

      selectedLanguage =
          prefs.getString("selectedLanguage") ??
              "English";
    });

    await applyVoiceSettings();
  }

  Future<void> applyVoiceSettings() async {
    try {
      await flutterTts.setSpeechRate(
        speechSpeed,
      );

      await flutterTts.setPitch(
        speechPitch,
      );

      if (selectedLanguage == "English") {
        await flutterTts.setLanguage(
          "en-US",
        );
      } else if (selectedLanguage == "Kannada") {
        await flutterTts.setLanguage(
          "kn-IN",
        );
      } else if (selectedLanguage == "Hindi") {
        await flutterTts.setLanguage(
          "hi-IN",
        );
      }

      await flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint(
        "TTS SETTINGS ERROR: $e",
      );
    }
  }

  Future<void> speakRecognizedText(
    String text,
  ) async {
    if (text.trim().isEmpty) return;
    if (!widget.isActive) return;

    try {
      await applyVoiceSettings();

      await flutterTts.stop();

      await flutterTts.speak(text);

      debugPrint(
        "TTS SPEAKING: $text",
      );
    } catch (e) {
      debugPrint(
        "TTS ERROR: $e",
      );
    }
  }

  Future<void> speakText() async {
    if (convertedText.isEmpty ||
        convertedText == "Waiting..." ||
        convertedText == "No Hand Detected") {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No valid sign to speak",
          ),
        ),
      );

      return;
    }

    await speakRecognizedText(
      convertedText,
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Future<void> loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      totalSignsRecognized =
          prefs.getInt(
                "totalSignsRecognized",
              ) ??
              0;

      lastDetectedSign =
          prefs.getString(
                "lastDetectedSign",
              ) ??
              "None";
    });
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      "sign_history",
      history,
    );
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final savedHistory =
        prefs.getStringList(
              "sign_history",
            ) ??
            [];

    if (!mounted) return;

    setState(() {
      history = savedHistory;
    });
  }

  // ============================================================
  // IMAGES
  // ============================================================

  Future<void> saveImages() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      "captured_images",
      capturedImages,
    );
  }

  Future<void> loadImages() async {
    final prefs = await SharedPreferences.getInstance();

    final savedImages =
        prefs.getStringList(
              "captured_images",
            ) ??
            [];

    if (!mounted) return;

    setState(() {
      capturedImages = savedImages;
    });
  }

  // ============================================================
  // CAPTURE IMAGE
  // ============================================================

  Future<void> captureImage() async {
    if (controller == null ||
        !controller!.value.isInitialized) {
      return;
    }

    if (isProcessingImage) return;

    try {
      isProcessingImage = true;

      if (mounted) {
        setState(() {
          isDetecting = true;
        });
      }

      final image = await controller!.takePicture();

      if (!mounted) return;

      setState(() {
        capturedImagePath = image.path;

        capturedImages.add(
          image.path,
        );

        capturedTime =
            DateTime.now().toString();
      });

      await saveImages();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Image Captured Successfully",
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        "CAPTURE ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    } finally {
      isProcessingImage = false;

      if (mounted) {
        setState(() {
          isDetecting = false;
        });
      }
    }
  }

  // ============================================================
  // CLEAR DATA
  // ============================================================

  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      detectedSign = "Waiting...";
      convertedText = "Waiting...";
      confidence = "0%";

      recognizedText = "";

      history.clear();

      totalSignsRecognized = 0;

      lastDetectedSign = "None";

      detectionCount = 0;

      lastRecognitionTime = null;
      lastProcessedFrameTime = null;
      lastSpokenTime = null;

      candidateSign = null;
      candidateCount = 0;
      spokenSign = null;

      isWaitingForLandmarkResult = false;
      isLandmarkFrameBusy = false;
    });

    await prefs.remove(
      "sign_history",
    );

    await prefs.remove(
      "totalSignsRecognized",
    );

    await prefs.remove(
      "lastDetectedSign",
    );

    await flutterTts.stop();
  }

  // ============================================================
  // RESET SCREEN
  // ============================================================

  void resetScreen() {
    if (!mounted) return;

    setState(() {
      capturedImagePath = "";
      capturedTime = "";

      detectedSign = "Waiting...";
      convertedText = "Waiting...";
      confidence = "0%";

      recognizedText = "";

      lastDetectedSign = "None";

      detectionCount = 0;

      lastRecognitionTime = null;
      lastProcessedFrameTime = null;
      lastSpokenTime = null;

      candidateSign = null;
      candidateCount = 0;
      spokenSign = null;

      isWaitingForLandmarkResult = false;
      isLandmarkFrameBusy = false;
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    detectionTimer?.cancel();

    landmarkSubscription?.cancel();

    try {
      controller?.stopImageStream();
    } catch (_) {}

    controller?.dispose();

    handLandmarker?.dispose();

    _modelService.dispose();

    flutterTts.stop();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final hasCamera =
        cameras.isNotEmpty &&
        selectedCameraIndex < cameras.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Sign Recognition",
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.cameraswitch,
            ),
            onPressed: switchCamera,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 300,
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    controller != null &&
                            controller!
                                .value
                                .isInitialized
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            child: Stack(
                              children: [
                                SizedBox.expand(
                                  child:
                                      CameraPreview(
                                    controller!,
                                  ),
                                ),

                                Center(
                                  child: Container(
                                    width: 220,
                                    height: 220,
                                    decoration:
                                        BoxDecoration(
                                      border:
                                          Border.all(
                                        color:
                                            Colors.green,
                                        width: 3,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    child:
                                        const Center(
                                      child: Text(
                                        "Place Hand Here",
                                        textAlign:
                                            TextAlign
                                                .center,
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.green,
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.black54,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                    child: Text(
                                      autoDetectEnabled
                                          ? "AUTO DETECT"
                                          : "PAUSED",
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                ),

                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  child: Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.black54,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                    child: Text(
                                      currentHandStatus,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                if (isDetecting)
                                  const Positioned(
                                    top: 10,
                                    right: 10,
                                    child: SizedBox(
                                      width: 25,
                                      height: 25,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),

                                Positioned(
                                  bottom: 15,
                                  right: 15,
                                  child:
                                      FloatingActionButton(
                                    heroTag:
                                        "captureBtn",
                                    onPressed:
                                        captureImage,
                                    child:
                                        const Icon(
                                      Icons.camera_alt,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(
                            height: 300,
                            child: Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      hasCamera &&
                              cameras[
                                      selectedCameraIndex]
                                  .lensDirection ==
                              CameraLensDirection
                                  .front
                          ? "Front Camera"
                          : "Rear Camera",
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.pan_tool,
                        ),
                        title: const Text(
                          "SignSpeak AI",
                        ),
                        subtitle: Text(
                          _modelService.isInitialized
                              ? "AI Model Ready (${_modelService.labels.length} Signs)"
                              : isHandDetectionReady
                                  ? "Loading ML Model..."
                                  : "Loading Hand Detection...",
                        ),
                        trailing: Icon(
                          _modelService.isInitialized
                              ? Icons.check_circle
                              : Icons.hourglass_top,
                          color:
                              _modelService.isInitialized
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),
Card(
  elevation: 4,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Text(
          "Detected Sign",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detectedSign,
          style: const TextStyle(
            fontSize: 36,
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Divider(),

        const SizedBox(height: 8),

        const Text(
          "Converted Text",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          convertedText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Divider(),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text(
                  "Confidence",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  confidence,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            Column(
              children: [
                const Text(
                  "Hand Status",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentHandStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
),

const SizedBox(height: 10),

Card(
  child: SwitchListTile(
    title: const Text(
      "Automatic Detection",
    ),
    subtitle: const Text(
      "Detect and speak signs automatically",
    ),
    value: autoDetectEnabled,
    onChanged: (value) {
      setState(() {
        autoDetectEnabled = value;
      });

      if (value && widget.isActive) {
        startAutomaticDetection();
      } else {
        stopAutomaticDetection();
      }
    },
    secondary: const Icon(
      Icons.record_voice_over,
    ),
  ),
),

const SizedBox(height: 10),

                    Card(
                      elevation: 4,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Detected Sign",
                              style:
                                  TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              detectedSign,
                              style:
                                  const TextStyle(
                                fontSize: 40,
                                color:
                                    Colors.deepPurple,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      elevation: 4,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Converted Text",
                              style:
                                  TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              convertedText,
                              textAlign:
                                  TextAlign.center,
                              style:
                                  const TextStyle(
                                fontSize: 30,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      elevation: 4,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Confidence",
                              style:
                                  TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              confidence,
                              style:
                                  const TextStyle(
                                fontSize: 26,
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.pan_tool,
                        ),
                        title: const Text(
                          "Hand Status",
                        ),
                        subtitle: Text(
                          currentHandStatus,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.numbers,
                        ),
                        title: Text(
                          "Total Signs Recognized: "
                          "$totalSignsRecognized",
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.photo,
                        ),
                        title: Text(
                          "Photos Captured: "
                          "${capturedImages.length}",
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.analytics,
                        ),
                        title: Text(
                          "Detections: "
                          "$detectionCount",
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.access_time,
                        ),
                        title: Text(
                          "Last Detection: "
                          "$lastDetectedSign",
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    if (capturedImagePath.isNotEmpty)
                      Column(
                        children: [
                          const Text(
                            "Captured Image",
                            style:
                                TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            child:
                                Image.file(
                              File(
                                capturedImagePath,
                              ),
                              height: 200,
                              width:
                                  double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(
                      height: 20,
                    ),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed:
                              speakText,
                          icon:
                              const Icon(
                            Icons.volume_up,
                          ),
                          label:
                              const Text(
                            "Speak",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed:
                              clearData,
                          icon:
                              const Icon(
                            Icons.delete,
                          ),
                          label:
                              const Text(
                            "Clear",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed:
                              resetScreen,
                          icon:
                              const Icon(
                            Icons.refresh,
                          ),
                          label:
                              const Text(
                            "Reset",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        HistoryScreen(
                                  history:
                                      history,
                                ),
                              ),
                            );
                          },
                          icon:
                              const Icon(
                            Icons.history,
                          ),
                          label:
                              const Text(
                            "History",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        GalleryScreen(
                                  images:
                                      capturedImages,
                                ),
                              ),
                            );
                          },
                          icon:
                              const Icon(
                            Icons.photo_library,
                          ),
                          label:
                              const Text(
                            "Gallery",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const AboutScreen(),
                              ),
                            );
                          },
                          icon:
                              const Icon(
                            Icons.info,
                          ),
                          label:
                              const Text(
                            "About",
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        StatsScreen(
                                  totalSigns:
                                      totalSignsRecognized,
                                  lastSign:
                                      lastDetectedSign,
                                ),
                              ),
                            );
                          },
                          icon:
                              const Icon(
                            Icons.analytics,
                          ),
                          label:
                              const Text(
                            "Stats",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}