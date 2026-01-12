import 'package:flutter/material.dart';
import 'package:alpr/data/database_helper.dart';
import 'package:alpr/presentation/home_page.dart';
import 'package:alpr/presentation/scanner_page.dart';
import 'package:alpr/presentation/records_page.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database factory for Desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize database
  // final dbHelper = DatabaseHelper.instance;
  // await dbHelper.database; // Lazy load instead to avoid factory race conditions
  
  runApp(const MyApp());
} 

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALPR Gate System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(fontSize: 16),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/scanner': (context) => const ScannerPage(),
        '/records': (context) => const RecordsPage(),
      },
    );
  }
}
