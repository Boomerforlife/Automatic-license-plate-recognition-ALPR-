import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'database_helper.dart';

class ExcelService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> importWhitelist() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        int count = 0;

        for (var table in excel.tables.keys) {
          for (var row in excel.tables[table]!.rows) {
            // Assume Row 0 is header: Plate, Owner, Details
            if (row.isEmpty) continue;
            
            // Skip header if it looks like one (optional check could be added here)
            // For now, assuming first row might be data or user manages headers.
            // Let's try to identify if it's a header or just import all unique entries.
            // Ideally, we skip row 0 if it contains "Plate Number" string.
             var plateCell = row[0];
             String plate = plateCell?.value?.toString() ?? '';
             
             if (plate.isEmpty || plate.toLowerCase().contains('plate')) continue;

             String owner = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
             String details = row.length > 2 ? (row[2]?.value?.toString() ?? '') : '';

             await _dbHelper.insertWhitelist({
               'plate_number': plate.replaceAll(' ', '').toUpperCase(), // Normalize
               'owner_name': owner,
               'details': details,
             });
             count++;
          }
        }
        return 'Successfully imported $count vehicles.';
      } else {
        return 'No file selected.';
      }
    } catch (e) {
      return 'Error importing file: $e';
    }
  }

  Future<String> exportLogs() async {
    try {
      // Request storage permission
      if (!await _requestPermission()) {
        return 'Permission denied. Cannot saving to Downloads.';
      }

      final logs = await _dbHelper.getAllLogs();
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Logs'];
      
      // Header
      sheetObject.appendRow([
        'ID', 
        'Plate Number', 
        'Timestamp', 
        'Status'
      ]);

      for (var log in logs) {
        sheetObject.appendRow([
          log['id'],
          log['plate_number'],
          log['timestamp'],
          log['status'],
        ]);
      }

      // Save to Downloads
      // Note: On Android 10+, limitations on accessing "Downloads" directly might exist without Scoped Storage.
      // But path_provider + standard file writing usually works for user-accessible folders if we use the correct directory.
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        // If that doesn't exist (unlikely), fall back to app docs (restricted visibility)
        if (!await directory.exists()) {
             directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory != null) {
        final now = DateTime.now();
        String timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
        String fileName = 'PlateLogs_$timestamp.xlsx';
        String filePath = join(directory.path, fileName);
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(excel.encode()!);
          
        return 'Logs exported to $filePath';
      } else {
        return 'Could not access storage directory.';
      }

    } catch (e) {
      return 'Error exporting logs: $e';
    }
  }

  Future<bool> _requestPermission() async {
    // For Android 11+ (API 30+), MANAGE_EXTERNAL_STORAGE is sometimes needed for broad access,
    // but for "Downloads" specifically or MediaStore, basic storage permissions might suffice or be deprecated.
    // However, sticking to legacy storage request for now as per common Flutter patterns.
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    // For Android 13+ (part of storage permission split)
    if (Platform.isAndroid) {
       // Check if logic needs adaptation for Android 13 visual/audio permissions?
       // Since we are dealing with .xlsx documents, checking Manage External Storage might be irrelevant if we use MediaStore,
       // but writing directly to /Download usually works with standard permission on older androids.
    }
    
    return status.isGranted;
  }
}
