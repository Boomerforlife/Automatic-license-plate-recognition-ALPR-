import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vibes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Whitelisted Vehicles Table
    await db.execute('''
    CREATE TABLE whitelisted_vehicles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plate_number TEXT NOT NULL UNIQUE,
      owner_name TEXT,
      details TEXT
    )
    ''');

    // Entry Logs Table
    await db.execute('''
    CREATE TABLE entry_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plate_number TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      status TEXT NOT NULL,
      owner_name TEXT,
      photo_path TEXT
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Drop and recreate for development phase or ALTER table if preserving data is critical
      // For this workflow, dropping is cleaner to ensure schema consistency
      await db.execute('DROP TABLE IF EXISTS entry_logs');
      await db.execute('''
      CREATE TABLE entry_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plate_number TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        owner_name TEXT,
        photo_path TEXT
      )
      ''');
    }
  }

  // Get vehicle by plate number
  Future<Map<String, dynamic>?> getVehicleByPlate(String plateNumber) async {
    final db = await instance.database;
    final result = await db.query(
      'whitelisted_vehicles',
      where: 'plate_number = ?',
      whereArgs: [plateNumber],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Log vehicle entry
  Future<int> logEntry({
    required String plateNumber,
    required bool isWhitelisted,
    String ownerName = 'Unknown',
    String? photoPath,
  }) async {
    final db = await instance.database;
    print('ALPR: Detected $plateNumber (Whitelisted: $isWhitelisted)');
    return await db.insert('entry_logs', {
      'plate_number': plateNumber,
      'timestamp': DateTime.now().toIso8601String(),
      'status': isWhitelisted ? 'whitelisted' : 'not_whitelisted',
      'owner_name': isWhitelisted ? ownerName : 'Unknown',
      'photo_path': photoPath,
    });
  }

  // CRUD Operations for Whitelist
  Future<int> insertWhitelist(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      'whitelisted_vehicles',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWhitelistedVehicle(String plate) async {
    final db = await instance.database;
    final maps = await db.query(
      'whitelisted_vehicles',
      columns: ['id', 'plate_number', 'owner_name', 'details'],
      where: 'plate_number = ?',
      whereArgs: [plate],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  Future<void> clearWhitelist() async {
    final db = await instance.database;
    await db.delete('whitelisted_vehicles');
  }

  // CRUD Operations for Logs
  Future<int> insertLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('entry_logs', row);
  }

  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final db = await instance.database;
    return await db.query('entry_logs', orderBy: 'timestamp DESC');
  }
}
