// lib/models/my_transaction.dart
enum TransactionType { income, expense }

class MyTransaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? note; // ข้อ 1: คอลัมน์ note สำหรับบันทึกรายละเอียด

  MyTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id, // ห้ามส่ง id ที่เป็น null เข้าไปใน UPDATE
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name, // เก็บเป็น 'income' หรือ 'expense'
      'note': note,
    };
  }

  factory MyTransaction.fromMap(Map<String, dynamic> map) {
    return MyTransaction(
      id: map['id'] as int,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      type: TransactionType.values.byName(map['type'] as String),
      note: map['note'] as String?, // แถวเก่าที่ยังไม่มี note จะได้เป็น null
    );
  }
}