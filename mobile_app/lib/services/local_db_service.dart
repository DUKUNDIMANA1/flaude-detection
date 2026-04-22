// lib/services/local_db_service.dart
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT UNIQUE NOT NULL,
        user_id INTEGER,
        amount REAL NOT NULL,
        merchant TEXT,
        merchant_category TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        card_type TEXT,
        card_last4 TEXT,
        transaction_type TEXT,
        channel TEXT,
        ip_address TEXT,
        device_id TEXT,
        timestamp TEXT,
        fraud_score REAL DEFAULT 0.0,
        is_fraud INTEGER DEFAULT 0,
        fraud_reasons TEXT,
        model_version TEXT,
        status TEXT DEFAULT 'pending',
        review_notes TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alert_id TEXT UNIQUE NOT NULL,
        transaction_id TEXT, -- Changed to TEXT to match transaction_id type
        alert_type TEXT,
        severity TEXT,
        title TEXT,
        message TEXT,
        is_read INTEGER DEFAULT 0,
        is_resolved INTEGER DEFAULT 0,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<int> insertTransaction(Transaction txn) async {
    final db = await database;
    return db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
    String? status,
    bool? isFraud,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> args = [];

    if (status != null) {
      whereClauses.add('status = ?');
      args.add(status);
    }
    if (isFraud != null) {
      whereClauses.add('is_fraud = ?');
      args.add(isFraud ? 1 : 0);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final maps = await db.query(
      'transactions',
      where: whereString,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<Transaction?> getTransactionById(String txnId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [txnId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Transaction.fromMap(maps.first);
  }

  Future<int> updateTransaction(Transaction txn) async {
    final db = await database;
    return db.update(
      'transactions',
      txn.toMap(),
      where: 'transaction_id = ?',
      whereArgs: [txn.transactionId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getTransactionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getFraudCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM transactions WHERE is_fraud = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getAvgFraudScore() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT AVG(fraud_score) as avg FROM transactions');
    // Important: result['avg'] can be an int (0) or double, cast to num first
    final value = result.first['avg'];
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  Future<int> insertAlert(Map<String, dynamic> alert) async {
    final db = await database;
    return db.insert('alerts', {
      'alert_id':       alert['alert_id'],
      'transaction_id': alert['transaction_id'],
      'alert_type':     alert['alert_type'],
      'severity':       alert['severity'],
      'title':          alert['title'],
      'message':        alert['message'],
      'is_read':        (alert['is_read'] == true) ? 1 : 0,
      'is_resolved':    (alert['is_resolved'] == true) ? 1 : 0,
      'created_at':     alert['created_at'],
      'synced':         1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAlerts({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final db = await database;
    return db.query(
      'alerts',
      where: unreadOnly ? 'is_read = 0' : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<int> getUnreadAlertCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM alerts WHERE is_read = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAlertRead(String alertId) async {
    final db = await database;
    await db.update('alerts', {'is_read': 1},
        where: 'alert_id = ?', whereArgs: [alertId]);
  }

  // ── Stats cache ───────────────────────────────────────────────────────────

  Future<void> cacheStats(String key, String value) async {
    final db = await database;
    await db.insert('cached_stats', {
      'key': key,
      'value': value,
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCachedStats(String key) async {
    final db = await database;
    final maps = await db.query('cached_stats',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> clearOldCache() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
    await db.delete('cached_stats',
        where: 'cached_at < ?', whereArgs: [cutoff]);
  }
}
