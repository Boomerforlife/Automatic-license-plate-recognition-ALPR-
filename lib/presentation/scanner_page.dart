import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/database_helper.dart';
import '../utils/plate_validator.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer();
  late final DatabaseHelper _databaseHelper;
  
  bool _isProcessing = false;
  
  // Viewfinder Settings
  final GlobalKey _cameraPreviewKey = GlobalKey();
  Rect? _scanWindowRect;
  bool _isScanWindowInitialized = false;

  @override
  void initState() {
    super.initState();
    _databaseHelper = DatabaseHelper.instance;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: ${e.toString()}')),
        );
      }
    }
  }

  void _onLayoutDone(_) {
    final renderBox = _cameraPreviewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && !_isScanWindowInitialized) {
      final size = renderBox.size;
      // Define a 250x150 box in the center
      setState(() {
        _scanWindowRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.8,
          height: 150,
        );
        _isScanWindowInitialized = true;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture Image
      final XFile file = await _controller!.takePicture();
      
      // 2. Save to Persistent Storage
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String persistentPath = path.join(directory.path, fileName);
      
      await File(file.path).copy(persistentPath);

      // 3. Create Input Image from persistent file
      final inputImage = InputImage.fromFilePath(persistentPath);
      
      // 4. Process with ML Kit
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      String bestCandidate = "";
      
      // 5. Analyze Text
      for (TextBlock block in recognizedText.blocks) {
        // Strict Regex Sanitization: Remove everything except A-Z, 0-9
        final String rawText = block.text.toUpperCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        
        // Prioritize a valid plate if found
        if (PlateValidator.isValidIndianPlate(rawText)) {
          bestCandidate = rawText;
          break;
        }
        // Fallback: Just take the largest text block if no valid plate found yet
        if (bestCandidate.isEmpty && rawText.length > 4) {
          bestCandidate = rawText;
        }
      }

      if (mounted) {
        await _showEditDialog(bestCandidate, persistentPath);
      }

    } catch (e) {
      debugPrint("Error taking picture: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showEditDialog(String detectedText, String imagePath) async {
    final TextEditingController textController = TextEditingController(text: detectedText);
     
    // Initial Check
    Map<String, dynamic>? vehicle = detectedText.isNotEmpty 
        ? await _databaseHelper.getVehicleByPlate(detectedText) 
        : null;
        
    String? ownerName = vehicle?['owner_name'];
    bool isWhitelisted = vehicle != null;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Plate'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Plate Number',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    onChanged: (value) async {
                      if (value.isNotEmpty) {
                        final v = await _databaseHelper.getVehicleByPlate(value.toUpperCase());
                        setState(() {
                          vehicle = v;
                          ownerName = v?['owner_name'];
                          isWhitelisted = v != null;
                        });
                      } else {
                         setState(() {
                          isWhitelisted = false;
                          ownerName = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (isWhitelisted) ...[
                    Text(
                      'Owner: $ownerName',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text('WHITELISTED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                     const SizedBox(height: 5),
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text('UNKNOWN / VISITOR', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final finalPlate = textController.text.trim().toUpperCase();
                    if (finalPlate.isNotEmpty) {
                       Navigator.pop(context);
                       await _saveLog(finalPlate, imagePath);
                    }
                  },
                  child: const Text('CONFIRM'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLog(String plateNumber, String photoPath) async {
    // Re-check database in case user edited the plate number
    final vehicle = await _databaseHelper.getVehicleByPlate(plateNumber);
    final isWhitelisted = vehicle != null;
    final ownerName = vehicle?['owner_name'] ?? 'Unknown';

    await _databaseHelper.logEntry(
      plateNumber: plateNumber,
      isWhitelisted: isWhitelisted,
      ownerName: ownerName,
      photoPath: photoPath,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged: $plateNumber'),
          backgroundColor: isWhitelisted ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Capture & Confirm")),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _controller != null) {
            WidgetsBinding.instance.addPostFrameCallback(_onLayoutDone);
            return Stack(
              children: [
                // 1. Camera Preview
                SizedBox.expand(
                  child: CameraPreview(_controller!, key: _cameraPreviewKey),
                ),
                
                // 2. Viewfinder Overlay
                if (_isScanWindowInitialized && _scanWindowRect != null)
                  CustomPaint(
                    painter: _ScanWindowPainter(
                      scanWindowRect: _scanWindowRect!,
                      isPlateDetected: false, // Static viewfinder for capture mode
                    ),
                    child: Container(),
                  ),

                // 3. Shutter Button
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed: _isProcessing ? null : _takePicture,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 40),
                    ),
                  ),
                ),

                // 4. Loading Overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Rect scanWindowRect;
  final bool isPlateDetected;

  _ScanWindowPainter({
    required this.scanWindowRect,
    required this.isPlateDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    final holePaint = Paint()..blendMode = BlendMode.dstOut;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindowRect, const Radius.circular(12)),
      holePaint,
    );
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindowRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) {
    return oldDelegate.scanWindowRect != scanWindowRect;
  }
}