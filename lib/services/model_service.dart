import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class RecognitionResult {
  final String label;
  final double confidence;
  final int index;
  final List<double> scores;

  const RecognitionResult({
    required this.label,
    required this.confidence,
    required this.index,
    required this.scores,
  });

  static const RecognitionResult empty = RecognitionResult(
    label: "No Hand Detected",
    confidence: 0.0,
    index: -1,
    scores: [],
  );

  static const RecognitionResult unknown = RecognitionResult(
    label: "Unknown",
    confidence: 0.0,
    index: -1,
    scores: [],
  );

  bool get isRecognized => index >= 0 && label != "Unknown" && label != "No Hand Detected";

  @override
  String toString() =>
      'RecognitionResult(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%, index: $index)';
}

/// Normalized bounding box with coordinates in [0.0, 1.0].
class NormalizedRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;

  /// Creates a square bounding box centered around the current box with a padding factor.
  NormalizedRect toSquareWithPadding([double paddingFactor = 1.35]) {
    final cx = (left + right) / 2.0;
    final cy = (top + bottom) / 2.0;
    final side = math.max(width, height) * paddingFactor;

    final halfSide = side / 2.0;
    return NormalizedRect(
      left: (cx - halfSide).clamp(0.0, 1.0),
      top: (cy - halfSide).clamp(0.0, 1.0),
      right: (cx + halfSide).clamp(0.0, 1.0),
      bottom: (cy + halfSide).clamp(0.0, 1.0),
    );
  }
}

class ModelService {
  static const String modelPath = "assets/models/signspeak_model.tflite";
  static const String labelsPath = "assets/models/labels.txt";
  static const int inputSize = 64;
  static const int numClasses = 29;

  /// Minimum confidence threshold for an inference to be accepted
  double confidenceThreshold = 0.50;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<String> get labels => List.unmodifiable(_labels);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint("Initializing ModelService...");

      // 1. Load labels
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      debugPrint("Loaded ${_labels.length} labels: $_labels");

      // 2. Load TFLite interpreter
      _interpreter = await Interpreter.fromAsset(modelPath);
      _interpreter!.allocateTensors();

      final inputDetails = _interpreter!.getInputTensors();
      final outputDetails = _interpreter!.getOutputTensors();

      debugPrint("TFLite Model loaded successfully.");
      debugPrint("Input shape: ${inputDetails.map((t) => t.shape).toList()}");
      debugPrint("Output shape: ${outputDetails.map((t) => t.shape).toList()}");

      _isInitialized = true;
    } catch (e) {
      debugPrint("Error initializing ModelService: $e");
      rethrow;
    }
  }

  /// Run inference on a prepared 64x64 RGB float32 input tensor.
  /// IMPORTANT: The model has an internal Rescaling layer (x/127.5 - 1.0),
  /// so pixel values MUST be in [0.0, 255.0] float32.
  RecognitionResult runInference(Float32List inputTensor) {
    if (!_isInitialized || _interpreter == null) {
      debugPrint("ModelService: Interpreter not initialized");
      return RecognitionResult.unknown;
    }

    try {
      final output = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );

      // Reshape flattened Float32List to [1, 64, 64, 3]
      _interpreter!.run(
        inputTensor.reshape([1, inputSize, inputSize, 3]),
        output,
      );

      final scores = output[0];
      int bestIndex = 0;
      double maxScore = scores[0];

      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          bestIndex = i;
        }
      }

      final predictedLabel = _labels[bestIndex];

      if (maxScore < confidenceThreshold) {
        return RecognitionResult(
          label: "Unknown",
          confidence: maxScore,
          index: bestIndex,
          scores: scores,
        );
      }

      return RecognitionResult(
        label: predictedLabel,
        confidence: maxScore,
        index: bestIndex,
        scores: scores,
      );
    } catch (e) {
      debugPrint("Inference error: $e");
      return RecognitionResult.unknown;
    }
  }

  /// Extracts a 64x64 RGB float32 tensor directly from an img.Image.
  Float32List preprocessImage(
    img.Image image, {
    NormalizedRect? cropRoi,
  }) {
    img.Image target = image;

    if (cropRoi != null) {
      final x = (cropRoi.left * image.width).toInt().clamp(0, image.width - 1);
      final y = (cropRoi.top * image.height).toInt().clamp(0, image.height - 1);
      final w = ((cropRoi.right - cropRoi.left) * image.width)
          .toInt()
          .clamp(1, image.width - x);
      final h = ((cropRoi.bottom - cropRoi.top) * image.height)
          .toInt()
          .clamp(1, image.height - y);

      target = img.copyCrop(image, x: x, y: y, width: w, height: h);
    }

    // Resize to 64x64
    if (target.width != inputSize || target.height != inputSize) {
      target = img.copyResize(
        target,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );
    }

    // Convert to Float32List in [0.0, 255.0]
    final tensor = Float32List(1 * inputSize * inputSize * 3);
    int ptr = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = target.getPixel(x, y);
        tensor[ptr++] = pixel.r.toDouble();
        tensor[ptr++] = pixel.g.toDouble();
        tensor[ptr++] = pixel.b.toDouble();
      }
    }

    return tensor;
  }

  /// Directly samples a 64x64 RGB float32 tensor from a CameraImage (YUV420 on Android)
  /// given a normalized ROI crop in the upright display frame.
  /// This takes < 1ms because only 4,096 pixels are converted rather than the whole 350,000-pixel frame.
  Float32List preprocessCameraImageFast({
    required CameraImage cameraImage,
    required NormalizedRect normalizedCrop,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    final tensor = Float32List(1 * inputSize * inputSize * 3);

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    final uRowStride = uPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;

    final vRowStride = vPlane.bytesPerRow;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    final sensorW = cameraImage.width;
    final sensorH = cameraImage.height;

    final cropL = normalizedCrop.left;
    final cropT = normalizedCrop.top;
    final cropR = normalizedCrop.right;
    final cropB = normalizedCrop.bottom;

    int ptr = 0;

    // For each pixel in the 64x64 output grid:
    for (int oy = 0; oy < inputSize; oy++) {
      // Normalized vertical coordinate in the upright crop:
      final uy = cropT + (oy + 0.5) / inputSize * (cropB - cropT);

      for (int ox = 0; ox < inputSize; ox++) {
        // Normalized horizontal coordinate in the upright crop:
        final ux = cropL + (ox + 0.5) / inputSize * (cropR - cropL);

        // Map upright normalized coordinates (ux, uy) to sensor pixel coordinates (sx, sy)
        int sx = 0;
        int sy = 0;

        if (sensorOrientation == 90) {
          // Rear camera typical: sensor is rotated 90 degrees clockwise relative to portrait
          // Upright X maps to sensor Y, Upright Y maps to sensor (1 - X)
          sx = ((1.0 - uy) * (sensorW - 1)).round().clamp(0, sensorW - 1);
          sy = (ux * (sensorH - 1)).round().clamp(0, sensorH - 1);
        } else if (sensorOrientation == 270) {
          // Front camera typical
          if (isFrontCamera) {
            // Mirrored portrait preview:
            sx = (uy * (sensorW - 1)).round().clamp(0, sensorW - 1);
            sy = (ux * (sensorH - 1)).round().clamp(0, sensorH - 1);
          } else {
            sx = (uy * (sensorW - 1)).round().clamp(0, sensorW - 1);
            sy = ((1.0 - ux) * (sensorH - 1)).round().clamp(0, sensorH - 1);
          }
        } else if (sensorOrientation == 180) {
          sx = ((1.0 - ux) * (sensorW - 1)).round().clamp(0, sensorW - 1);
          sy = ((1.0 - uy) * (sensorH - 1)).round().clamp(0, sensorH - 1);
        } else {
          // 0 degrees
          sx = (ux * (sensorW - 1)).round().clamp(0, sensorW - 1);
          sy = (uy * (sensorH - 1)).round().clamp(0, sensorH - 1);
        }

        // YUV to RGB conversion at (sx, sy)
        final yIndex = sy * yRowStride + sx * yPixelStride;
        final uvX = sx >> 1;
        final uvY = sy >> 1;
        final uIndex = uvY * uRowStride + uvX * uPixelStride;
        final vIndex = uvY * vRowStride + uvX * vPixelStride;

        if (yIndex < yBytes.length && uIndex < uBytes.length && vIndex < vBytes.length) {
          final yVal = yBytes[yIndex];
          final uVal = uBytes[uIndex];
          final vVal = vBytes[vIndex];

          // Standard YUV420 to RGB formulas
          final r = (yVal + 1.402 * (vVal - 128)).clamp(0.0, 255.0);
          final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0.0, 255.0);
          final b = (yVal + 1.772 * (uVal - 128)).clamp(0.0, 255.0);

          tensor[ptr++] = r;
          tensor[ptr++] = g;
          tensor[ptr++] = b;
        } else {
          tensor[ptr++] = 0.0;
          tensor[ptr++] = 0.0;
          tensor[ptr++] = 0.0;
        }
      }
    }

    return tensor;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
