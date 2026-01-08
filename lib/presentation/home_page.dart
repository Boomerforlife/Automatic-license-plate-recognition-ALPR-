import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibes/data/excel_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _checkAndRequestPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALPR Gate System', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Start Scanning Button
              _buildButton(
                context,
                'START SCANNING',
                Icons.camera_alt_rounded,
                Colors.green,
                () async {
                  await _checkAndRequestPermission();
                  if (await Permission.camera.isGranted) {
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, '/scanner');
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Preload Data Button
              _buildButton(
                context,
                'PRELOAD DATA',
                Icons.upload_file_rounded,
                Colors.blue,
                () async {
                  final excelService = ExcelService();
                  final result = await excelService.importWhitelist();
                  final success = result != null && result.isNotEmpty;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Data imported successfully!' : 'Failed to import data: $result'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // View Records Button
              _buildButton(
                context,
                'VIEW RECORDS',
                Icons.list_alt_rounded,
                Colors.purple,
                () {
                  Navigator.pushNamed(context, '/records');
                },
              ),
              const SizedBox(height: 24),
              
              // Export Excel Button
              _buildButton(
                context,
                'EXPORT EXCEL',
                Icons.download_rounded,
                Colors.orange,
                () async {
                  final excelService = ExcelService();
                  final result = await excelService.exportLogs();
                  final success = result != null && result.isNotEmpty;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 32),
        label: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
