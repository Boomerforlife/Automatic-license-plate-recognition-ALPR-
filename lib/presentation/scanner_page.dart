import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibes/data/database_helper.dart';
import 'package:vibes/data/plate_validator.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  bool _isProcessing = false;
  bool _isStreamRunning = false;
  String _lastDetectedPlate = '';
  DateTime? _lastDetectionTime;
  static const int _cooldownSeconds = 3;
  Color _flashColor = Colors.transparent;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: Initializing ScannerPage...');
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('DEBUG: Getting available cameras...');
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }
      
      print('DEBUG: Creating camera controller...');
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium, // Using medium for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      print('DEBUG: Initializing camera controller...');
      _initializeControllerFuture = _controller.initialize();
      
      // Wait for initialization to complete
      await _initializeControllerFuture.whenComplete(() {
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          print('DEBUG: Camera controller initialized successfully');
          
          // Start image stream after initialization
          if (_controller.value.isInitialized) {
            _startImageStream();
          } else {
            print('WARNING: Camera controller not properly initialized');
          }
        }
      });
    } catch (e) {
      print('ERROR in _initializeCamera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _startImageStream() {
    // Safety checks
    if (_controller == null || !_controller.value.isInitialized) {
      print('ERROR: Cannot start image stream - controller not initialized');
      return;
    }
    
    // Prevent multiple streams
    if (_isStreamRunning) {
      print('DEBUG: Image stream already running');
      return;
    }
    
    print('DEBUG: Starting image stream...');
    
    try {
      _controller.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      if (_lastDetectionTime != null &&
          DateTime.now().difference(_lastDetectionTime!).inSeconds < _cooldownSeconds) {
        return;
      }

      _isProcessing = true;
      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();
        final InputImage inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormatValue.fromRawValue(image.format.raw) ??
                InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        await _processImage(inputImage);
      } catch (e) {
        debugPrint('Error processing image: $e');
      } finally {
        _isProcessing = false;
      }
    });
    
    _isStreamRunning = true;
    print('DEBUG: Image stream started successfully');
    
    } catch (e) {
      print('ERROR in _startImageStream: $e');
      _isStreamRunning = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera stream error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      for (final textBlock in recognizedText.blocks) {
        for (final line in textBlock.lines) {
          final plateNumber = line.text.trim().toUpperCase();
          
          // Check if it's a valid Indian license plate
          if (PlateValidator.isValidIndianPlate(plateNumber) && 
              _lastDetectedPlate != plateNumber) {
            
            _lastDetectedPlate = plateNumber;
            _lastDetectionTime = DateTime.now();
            debugPrint('ALPR: Detected $plateNumber');
            
            // Pause the camera stream
            await _controller.pausePreview();
            
            // Show the confirmation dialog
            if (mounted) {
              await _showPlateConfirmationDialog(plateNumber);
              // Resume the camera after dialog is closed
              if (mounted) {
                await _controller.resumePreview();
              }
            }
            
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error in text recognition: $e');
      if (mounted) {
        await _controller.resumePreview();
      }
    }
  }
  
  Future<void> _showPlateConfirmationDialog(String plateNumber) async {
    final vehicle = await _databaseHelper.getVehicleByPlate(plateNumber);
    final isWhitelisted = vehicle != null;
    final ownerName = vehicle?['owner_name'] ?? 'Unknown';
    
    final TextEditingController plateController = TextEditingController(text: plateNumber);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Detected License Plate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: plateController,
                decoration: const InputDecoration(
                  labelText: 'Plate Number',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Status: '),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isWhitelisted ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isWhitelisted ? 'WHITELISTED' : 'UNKNOWN',
                      style: TextStyle(
                        color: isWhitelisted ? Colors.green[800] : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (isWhitelisted) ...[
                const SizedBox(height: 8),
                Text('Owner: $ownerName'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final plateToSave = plateController.text.trim().toUpperCase();
                if (plateToSave.isNotEmpty) {
                  await _databaseHelper.logEntry(
                    plateNumber: plateToSave,
                    isWhitelisted: isWhitelisted,
                    ownerName: isWhitelisted ? ownerName : 'Unknown',
                  );
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Entry added: $plateToSave'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('ADD ENTRY'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    print('DEBUG: Disposing ScannerPage resources');
    _controller.dispose();
    textRecognizer.close();
    print('DEBUG: TextRecognizer disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          // Flash overlay
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _flashColor,
          ),
          // Manual entry button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _showManualEntryDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.keyboard_alt_outlined, size: 30),
            ),
          ),
          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Plate Number'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., KA01MG1234',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 18),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final plateNumber = controller.text.trim().toUpperCase();
                if (plateNumber.isNotEmpty) {
                  Navigator.of(context).pop();
                  _processManualEntry(plateNumber);
                }
              },
              child: const Text('SUBMIT'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processManualEntry(String plateNumber) async {
    if (!PlateValidator.isValidIndianPlate(plateNumber)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid plate number format. Please use format like KA01MG1234'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final vehicle = await _databaseHelper.getVehicleByPlate(plateNumber);
    
    if (!mounted) return;
    
    setState(() {
      _flashColor = vehicle != null ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5);
    });
    
    // Show plate number and owner (if whitelisted)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vehicle != null 
            ? 'Welcome, ${vehicle['owner_name']}!' 
            : 'Vehicle not registered: $plateNumber',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: vehicle != null ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Log the entry
    await _databaseHelper.logEntry(
      plateNumber: plateNumber,
      isWhitelisted: vehicle != null,
      ownerName: vehicle?['owner_name'] ?? 'Unknown',
    );
    
    // Reset flash color after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _flashColor = Colors.transparent;
        });
      }
    });
  }
}
