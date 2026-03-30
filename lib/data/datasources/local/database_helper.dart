import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/transaction_model.dart';

class DatabaseHelper {
  static const String _dbName = "finance_tracker.db";
  static const int _dbVersion = 4;

  static const String _tableTransactions = "transactions";
  static const String _tableCategories = "categories";
  static const String _tableBudgets = "budgets";

  // Singleton pattern
  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
    }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Tạo DB lần đầu
  Future<void> _createDB(Database db, int version) async {
    // Transactions
    await db.execute('''
      CREATE TABLE $_tableTransactions (
        id TEXT PRIMARY KEY,
        title TEXT,
        amount REAL,
        date TEXT,
        category TEXT,
        isExpense INTEGER,
        user_id TEXT
      )
    ''');

    // Budgets
    await db.execute('''
      CREATE TABLE $_tableBudgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        amount REAL NOT NULL,
        user_id TEXT,
        UNIQUE(month, year, user_id)
      )
    ''');

    // Categories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableCategories(
        id TEXT PRIMARY KEY,
        name TEXT,
        color INTEGER,
        isExpense INTEGER,
        user_id TEXT,
        is_protected INTEGER DEFAULT 0,
        keywords TEXT
      )
    ''');

    // Insert default protected categories (shared, user_id = NULL)
    await _insertDefaultCategories(db);
  }

  // Nâng version DB
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: thêm user_id cho transactions (nếu DB cũ chưa có)
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $_tableTransactions ADD COLUMN user_id TEXT',
      );
    }

    // v3: tạo bảng budgets
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableBudgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          amount REAL NOT NULL,
          user_id TEXT,
          UNIQUE(month, year, user_id)
        )
      ''');
    }

    // v4: tạo bảng categories
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableCategories(
          id TEXT PRIMARY KEY,
          name TEXT,
          color INTEGER,
          isExpense INTEGER,
          user_id TEXT,
          is_protected INTEGER DEFAULT 0,
          keywords TEXT
        )
      ''');
      await _insertDefaultCategories(db);
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    // Default expense categories E1..E11 and income I1..I5
    final defaults = <Map<String, dynamic>>[
      {'id': 'E1', 'name': 'Ăn uống'},
      {'id': 'E2', 'name': 'Di chuyển'},
      {'id': 'E3', 'name': 'Dịch vụ sinh hoạt'},
      {'id': 'E4', 'name': 'Siêu thị/Cửa hàng'},
      {'id': 'E5', 'name': 'Trang phục/Làm đẹp'},
      {'id': 'E6', 'name': 'Sức khỏe'},
      {'id': 'E7', 'name': 'Giáo dục'},
      {'id': 'E8', 'name': 'Giải trí/Du lịch'},
      {'id': 'E9', 'name': 'Hiếu hỉ/Xã giao'},
      {'id': 'E10', 'name': 'Gia đình/Con cái'},
      {'id': 'E11', 'name': 'Khác'},
      {'id': 'I1', 'name': 'Lương'},
      {'id': 'I2', 'name': 'Thưởng'},
      {'id': 'I3', 'name': 'Khác'},
    ];

    final batch = db.batch();
    for (final d in defaults) {
      batch.insert(_tableCategories, d, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ===================== CATEGORIES CRUD =====================

  Future<int> insertCategory(dynamic categoryMap) async {
    final db = await instance.database;
    return db.insert(_tableCategories, categoryMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> _rawGetAllCategories({String? userId}) async {
    final db = await instance.database;
    if (userId != null) {
      return await db.query(_tableCategories, where: 'user_id = ?', whereArgs: [userId]);
    }
    return await db.query(_tableCategories);
  }

  Future<List<Map<String, Object?>>> getAllCategories({String? userId}) async {
    return _rawGetAllCategories(userId: userId);
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return db.delete(_tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCategory(String id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return db.update(_tableCategories, values, where: 'id = ?', whereArgs: [id]);
  }

  // ===================== TRANSACTIONS CRUD =====================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return db.insert(_tableTransactions, transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions({String? userId}) async {
    final db = await instance.database;

    final List<Map<String, Object?>> result;
    if (userId != null) {
      result = await db.query(
        _tableTransactions,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );
    } else {
      result = await db.query(_tableTransactions, orderBy: 'date DESC');
    }

    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return db.delete(_tableTransactions, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await instance.database;

    final placeholders = List.filled(ids.length, '?').join(',');
    return db.delete(
      _tableTransactions,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return db.update(
      _tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<Map<String, double>> getTotalIncomeExpense({String? userId}) async {
    final db = await instance.database;

    final List<Map<String, Object?>> result;
    if (userId != null) {
      result = await db.rawQuery(
        "SELECT isExpense, SUM(amount) as total FROM $_tableTransactions WHERE user_id = ? GROUP BY isExpense",
        [userId],
      );
    } else {
      result = await db.rawQuery(
        "SELECT isExpense, SUM(amount) as total FROM $_tableTransactions GROUP BY isExpense",
      );
    }

    double income = 0;
    double expense = 0;

    for (final row in result) {
      final isExpense = row['isExpense'] as int?;
      final total = (row['total'] as num?)?.toDouble() ?? 0;

      if (isExpense == 0) {
        income = total;
      } else {
        expense = total;
      }
    }

    return {'income': income, 'expense': expense};
  }

  // ===================== BUDGET =====================

  Future<void> upsertBudget({
    required int month,
    required int year,
    required double amount,
    String? userId,
  }) async {
    final db = await instance.database;

    await db.insert(
      _tableBudgets,
      {
        'month': month,
        'year': year,
        'amount': amount,
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double?> getBudgetAmount({
    required int month,
    required int year,
    String? userId,
  }) async {
    final db = await instance.database;

    final res = await db.query(
      _tableBudgets,
      columns: ['amount'],
      where: 'month = ? AND year = ? AND user_id = ?',
      whereArgs: [month, year, userId],
      limit: 1,
    );

    if (res.isEmpty) return null;
    return (res.first['amount'] as num).toDouble();
  }
}
