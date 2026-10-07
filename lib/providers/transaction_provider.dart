// lib/providers/transaction_provider.dart
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/my_transaction.dart';

class TransactionProvider with ChangeNotifier {
  static const String _dbName = 'expenses.db';
  static const String _tableName = 'transactions';
  Database? _database;
  List<MyTransaction> _transactions = [];
  double _balance = 0; // ข้อ 2: ยอดคงเหลือที่คำนวณด้วย SUM ในฐานข้อมูล

  List<MyTransaction> get transactions => [..._transactions];
  double get balance => _balance;

  TransactionProvider() {
    fetchAndSetTransactions(); // โหลดข้อมูลเมื่อ Provider ถูกสร้าง
  }

  // กระบวนการที่ 2: การสร้างฐานข้อมูล
  Future<void> _initDatabase() async {
    if (_database != null) return;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      _database = await openDatabase(
        path,
        version: 2, // ข้อ 1: เพิ่มเวอร์ชันฐานข้อมูลเป็น 2
        onCreate: (db, version) {
          print('Creating table $_tableName...');
          return db.execute(
            'CREATE TABLE $_tableName(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type TEXT, note TEXT)',
          );
        },
        // ข้อ 1 (หัวข้อ 13.8): อัปเกรดฐานข้อมูลรุ่นเก่าโดยไม่ต้องลบข้อมูลเดิม
        onUpgrade: (db, oldVersion, newVersion) async {
          print('Upgrading database from $oldVersion to $newVersion...');
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE $_tableName ADD COLUMN note TEXT');
          }
        },
      );
      print('Database initialized at $path');
      final columns = await _database!.rawQuery('PRAGMA table_info($_tableName)');
      print('Columns: ${columns.map((c) => c['name']).join(', ')}');
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  // ขั้นตอนก่อนหน้า: ข้อมูลตัวอย่าง 'เงินเดือน' จะถูกเพิ่มให้อัตโนมัติเมื่อฐานข้อมูลยังว่าง
  Future<void> _seedIfEmpty() async {
    await _initDatabase();
    if (_database == null) return;

    final rows = await _database!.rawQuery('SELECT COUNT(*) AS c FROM $_tableName');
    final count = (rows.first['c'] as num?)?.toInt() ?? 0;
    if (count > 0) return;

    final id = await _database!.insert(
      _tableName,
      MyTransaction(
        title: 'เงินเดือน',
        amount: 25000,
        date: DateTime.now(),
        type: TransactionType.income,
      ).toMap(),
    );
    print('Seeded salary transaction with id: $id');
  }

  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type, {
    String? note, // ข้อ 1: รายละเอียดเพิ่มเติมของรายการ
  }) async {
    await _initDatabase(); // ตรวจสอบว่า DB พร้อมใช้งาน
    if (_database == null) return;

    final newTransaction = MyTransaction(
      title: title,
      amount: amount,
      date: date,
      type: type,
      note: note,
    );

    final id = await _database!.insert(_tableName, newTransaction.toMap());
    print('Inserted transaction with id: $id');
    await fetchAndSetTransactions(); // กระบวนการที่ 4: โหลดข้อมูลใหม่และแจ้ง UI
  }

  Future<void> fetchAndSetTransactions() async {
    await _initDatabase();
    if (_database == null) return;

    await _seedIfEmpty(); // มีข้อมูลแล้วจะข้ามไป

    final dataList = await _database!.query(_tableName, orderBy: 'date DESC');
    _transactions = dataList
        .map((item) => MyTransaction.fromMap(item))
        .toList();
    _balance = await fetchBalanceFromDb(); // ข้อ 2: SUM ในฐานข้อมูล
    print('Fetched ${_transactions.length} transactions.');
    notifyListeners(); // แจ้ง UI ให้วาดใหม่
  }

  // ข้อ 2: ยอดคงเหลือ = SUM ในฐานข้อมูล (ไม่โหลดทุกแถวมาบวกใน Dart)
  Future<double> fetchBalanceFromDb() async {
    await _initDatabase();
    if (_database == null) return 0;

    final rows = await _database!.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) AS balance "
      'FROM $_tableName',
    );
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  // แบบเทียบ: วนบวกใน Dart จากข้อมูลที่โหลดมาแล้ว
  double calculateBalanceByLooping() {
    var total = 0.0;
    for (final tx in _transactions) {
      total += tx.type == TransactionType.income ? tx.amount : -tx.amount;
    }
    return total;
  }

  // ข้อ 2: จับเวลาเปรียบเทียบ SUM ใน SQL กับการโหลดทุกแถวมาบวกใน Dart
  Future<
    ({double sqlBalance, double dartBalance, int sqlMicros, int dbToDartMicros, int inMemoryMicros, int rowCount})
  >
  compareBalanceMethods() async {
    await _initDatabase();
    if (_database == null) {
      return (sqlBalance: 0.0, dartBalance: 0.0, sqlMicros: 0, dbToDartMicros: 0, inMemoryMicros: 0, rowCount: 0);
    }

    final swSql = Stopwatch()..start();
    final sqlBalance = await fetchBalanceFromDb();
    swSql.stop();

    final swDbToDart = Stopwatch()..start();
    final data = await _database!.query(_tableName);
    var dartBalance = 0.0;
    for (final row in data) {
      final amount = (row['amount'] as num).toDouble();
      final isIncome = row['type'] == TransactionType.income.name;
      dartBalance += isIncome ? amount : -amount;
    }
    swDbToDart.stop();

    final swInMemory = Stopwatch()..start();
    calculateBalanceByLooping();
    swInMemory.stop();

    return (
      sqlBalance: sqlBalance,
      dartBalance: dartBalance,
      sqlMicros: swSql.elapsedMicroseconds,
      dbToDartMicros: swDbToDart.elapsedMicroseconds,
      inMemoryMicros: swInMemory.elapsedMicroseconds,
      rowCount: data.length,
    );
  }

  // ข้อ 3 (หัวข้อ 13.9): นำเข้ารายการตัวอย่าง 2 แบบ เพื่อจับเวลาเปรียบเทียบ
  Future<Duration> importSampleTransactions({
    required int count,
    required bool useBatch,
  }) async {
    return useBatch
        ? _importWithBatch(count)
        : _importWithAddTransaction(count);
  }

  // แบบที่ 1: เรียก addTransaction ทีละรายการ (แต่ละครั้งจะโหลดข้อมูลกลับด้วย)
  Future<Duration> _importWithAddTransaction(int count) async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      await addTransaction(
        'รายการนำเข้า ${i + 1}',
        ((i % 9) + 1) * 10.0,
        DateTime.now().subtract(Duration(minutes: i)),
        i.isEven ? TransactionType.expense : TransactionType.income,
        note: 'ข้อมูลตัวอย่างหมายเลข ${i + 1}',
      );
    }
    sw.stop();
    return sw.elapsed;
  }

  // แบบที่ 2: batch ภายใน transaction (insert ทั้งชุดในครั้งเดียว)
  Future<Duration> _importWithBatch(int count) async {
    await _initDatabase();
    if (_database == null) return Duration.zero;

    final sw = Stopwatch()..start();
    await _database!.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < count; i++) {
        batch.insert(
          _tableName,
          MyTransaction(
            title: 'รายการนำเข้า ${i + 1}',
            amount: ((i % 9) + 1) * 10.0,
            date: DateTime.now().subtract(Duration(minutes: i)),
            type: i.isEven ? TransactionType.expense : TransactionType.income,
            note: 'ข้อมูลตัวอย่างหมายเลข ${i + 1}',
          ).toMap(),
        );
      }
      await batch.commit(noResult: true);
    });
    sw.stop();

    await fetchAndSetTransactions(); // โหลดรายการใหม่ + ยอดคงเหลือ (นอกเวลาที่จับ)
    return sw.elapsed;
  }

  Future<void> updateTransaction(int id, MyTransaction newTransaction) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.update(
      _tableName,
      newTransaction.toMap(), // toMap() ไม่ส่ง id ที่เป็น null จึงไม่ไปเปลี่ยนคีย์หลัก
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  // กระบวนการที่ 6: การ Delete
  Future<void> deleteTransaction(int id) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }
}