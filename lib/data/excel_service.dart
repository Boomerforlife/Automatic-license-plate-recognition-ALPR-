import 'dart:io';
import 'package:excel/excel.dart'; // Keep for importWhitelist if needed, or remove if unused. Assuming importWhitelist uses it.
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
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
      
      // Create a new Excel Document
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Vibes Report';

      // 1. Headers
      final List<String> headers = ['S.No', 'Date', 'Time', 'Plate Number', 'Status', 'Photo'];
      for (int i = 0; i < headers.length; i++) {
        final xlsio.Range cell = sheet.getRangeByIndex(1, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
      }
      
      // Setup columns width
      sheet.getRangeByIndex(1, 1).columnWidth = 8;  // S.No
      sheet.getRangeByIndex(1, 2).columnWidth = 15; // Date
      sheet.getRangeByIndex(1, 3).columnWidth = 15; // Time
      sheet.getRangeByIndex(1, 4).columnWidth = 20; // Plate
      sheet.getRangeByIndex(1, 5).columnWidth = 20; // Status
      sheet.getRangeByIndex(1, 6).columnWidth = 30; // Photo

      // 2. Add Data and Photos
      for (int i = 0; i < logs.length; i++) {
        final log = logs[i];
        final int rowIndex = i + 2;
        
        // Parse Timestamp
        DateTime dt = DateTime.tryParse(log['timestamp']) ?? DateTime.now();
        String date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        String time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        // S.No
        sheet.getRangeByIndex(rowIndex, 1).setNumber((i + 1).toDouble());
        
        // Date & Time
        sheet.getRangeByIndex(rowIndex, 2).setText(date);
        sheet.getRangeByIndex(rowIndex, 3).setText(time);
        
        // Plate & Status
        sheet.getRangeByIndex(rowIndex, 4).setText(log['plate_number']);
        sheet.getRangeByIndex(rowIndex, 5).setText(log['status']);

        // Photo
        String? photoPath = log['photo_path'];
        if (photoPath != null && photoPath.isNotEmpty) {
           final File photoFile = File(photoPath);
           if (await photoFile.exists()) {
             final List<int> bytes = await photoFile.readAsBytes();
             // Set Row Height to accommodate image
             sheet.setRowHeightInPixels(rowIndex, 80);
             
             // Add Picture
             final xlsio.Picture picture = sheet.pictures.addStream(rowIndex, 6, bytes);
             picture.height = 70;
             picture.width = 100;
           } else {
             sheet.getRangeByIndex(rowIndex, 6).setText('File not found');
           }
        } else {
           sheet.getRangeByIndex(rowIndex, 6).setText('No Photo');
        }
      }

      // Save to Downloads
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
             directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory != null) {
        String fileName = 'Vibes_Report.xlsx';
        String filePath = join(directory.path, fileName);
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
          
        return 'Report saved to Downloads as Vibes_Report.xlsx!';
      } else {
        return 'Could not access storage directory.';
      }

    } catch (e) {
      return 'Error exporting logs: $e';
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.status.isGranted) {
        return true;
      }
      
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      if (await Permission.storage.request().isGranted) {
        return true;
      }
      
      return false;
    }
    return true;
  }
}
