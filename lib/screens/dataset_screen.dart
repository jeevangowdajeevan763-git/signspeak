import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DatasetScreen extends StatefulWidget {
  const DatasetScreen({super.key});

  @override
  State<DatasetScreen> createState() => _DatasetScreenState();
}

class _DatasetScreenState extends State<DatasetScreen> {
  CameraController? _controller;

  bool _isCameraReady = false;
  bool _isCapturing = false;

  String _selectedLabel = 'A';

  int _capturedCount = 0;
  int _countdown = 0;

  final int _targetImages = 100;

  final List<String> _labels = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    'DEL',
    'NOTHING',
    'SPACE',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) return;

      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<Directory> _getDatasetDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final datasetDirectory = Directory(
      '${appDirectory.path}/dataset_capture/$_selectedLabel',
    );

    if (!await datasetDirectory.exists()) {
      await datasetDirectory.create(recursive: true);
    }

    return datasetDirectory;
  }

  Future<void> _firstCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!_isCapturing || !mounted) return;

      setState(() {
        _countdown = i;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    setState(() {
      _countdown = 0;
    });
  }

  Future<void> _startCapture() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _capturedCount = 0;
      _countdown = 0;
    });

    final directory = await _getDatasetDirectory();

    await _firstCountdown();

    if (!_isCapturing || !mounted) return;

    for (int i = 1; i <= _targetImages; i++) {
      if (!_isCapturing || !mounted) break;

      try {
        final XFile image = await _controller!.takePicture();

        final fileName =
            '${_selectedLabel}_${i.toString().padLeft(3, '0')}.jpg';

        final newPath = '${directory.path}/$fileName';

        await File(image.path).copy(newPath);

        if (!mounted) return;

        setState(() {
          _capturedCount = i;
        });

        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('Capture error: $e');
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _countdown = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Captured $_capturedCount images for $_selectedLabel',
        ),
      ),
    );
  }

  void _stopCapture() {
    if (!_isCapturing) return;

    setState(() {
      _isCapturing = false;
      _countdown = 0;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SignSpeak Dataset Collector'),
      ),
      body: !_isCameraReady
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.black,
                        child: CameraPreview(_controller!),
                      ),
                      if (_countdown > 0)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_countdown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text(
                        'Keep your hand clearly inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Keep the hand large, steady and well lit',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<String>(
                        value: _selectedLabel,
                        isExpanded: true,
                        items: _labels.map((label) {
                          return DropdownMenuItem<String>(
                            value: label,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 18),
                            ),
                          );
                        }).toList(),
                        onChanged: _isCapturing
                            ? null
                            : (value) {
                                if (value == null) return;

                                setState(() {
                                  _selectedLabel = value;
                                  _capturedCount = 0;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_capturedCount / $_targetImages',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_isCapturing)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startCapture,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              'Start Capturing $_selectedLabel',
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _stopCapture,
                            icon: const Icon(Icons.stop),
                            label: const Text('STOP'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}