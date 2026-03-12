import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  LocalDatabaseService();

  static const String databaseName = 'korubeni.db';
  static const int databaseVersion = 1;

  Database? _database;

  Future<void> initialize() async {
    await database;
  }

  Future<Database> get database async {
    final db = _database;
    if (db != null) {
      return db;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$databaseName';
    _database = await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        is_primary INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE activity_events(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE crash_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        error TEXT NOT NULL,
        stack TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recordings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encrypted_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        size_bytes INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _onCreate(db, newVersion);
    }
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      await txn.delete('activity_events');
      await txn.delete('crash_logs');
      await txn.delete('recordings');
      await txn.delete('app_settings');
    });
  }

  Future<void> deleteDatabaseFile() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$databaseName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
