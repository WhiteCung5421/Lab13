import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/my_transaction.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายรับ-รายจ่าย'),
        actions: [
          // ข้อ 3: ปุ่มนำเข้ารายการตัวอย่าง 100 รายการ (2 แบบ)
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'นำเข้ารายการตัวอย่าง 100 รายการ',
            onPressed: () => _showImportOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ข้อ 2: ยอดคงเหลือใต้ AppBar คำนวณด้วย SUM ในฐานข้อมูล
          Consumer<TransactionProvider>(
            builder: (context, txProvider, child) {
              final balance = txProvider.balance;
              return Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  'ยอดคงเหลือ: ${balance.toStringAsFixed(2)} บาท',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<TransactionProvider>(
        builder: (context, txProvider, child) => txProvider.transactions.isEmpty
            ? const Center(child: Text('ไม่มีรายการ'))
            : ListView.builder(
                itemCount: txProvider.transactions.length,
                itemBuilder: (ctx, i) {
                  final tx = txProvider.transactions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        tx.type == TransactionType.income ? 'รับ' : 'จ่าย',
                      ),
                    ),
                    title: Text(tx.title),
                    subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                    // กดที่รายการเพื่อเปิดฟอร์มแก้ไข ส่งข้อมูล tx ไปด้วย
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddEditTransactionScreen(transaction: tx),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${tx.amount.toStringAsFixed(2)} บาท',
                          style: TextStyle(
                            color: tx.type == TransactionType.income
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () {
                            // เรียกเมธอด delete
                            context
                                .read<TransactionProvider>()
                                .deleteTransaction(tx.id!);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ), // ปิด Consumer ของรายการ
          ), // ปิด Expanded
        ], // ปิด children ของ Column
      ), // ปิด Column
      // ปุ่ม + เปิดหน้าฟอร์มเพิ่มรายการใหม่
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ข้อ 3: เลือกวิธีนำเข้ารายการตัวอย่าง 100 รายการ
  Future<void> _showImportOptions(BuildContext context) async {
    final useBatch = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('นำเข้ารายการตัวอย่าง 100 รายการ'),
              subtitle: Text('เลือกวิธีนำเข้าเพื่อจับเวลาเปรียบเทียบ'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('แบบที่ 1: เรียก addTransaction ทีละรายการ'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('แบบที่ 2: Batch ภายใน Transaction'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (useBatch == null || !context.mounted) return;
    await _runImport(context, useBatch: useBatch);
  }

  // รันนำเข้า แล้วแสดงเวลาที่ใช้ + ผลเปรียบเทียบยอดคงเหลือ
  Future<void> _runImport(
    BuildContext context, {
    required bool useBatch,
  }) async {
    final provider = context.read<TransactionProvider>();
    final method = useBatch
        ? 'Batch ภายใน Transaction'
        : 'addTransaction ทีละรายการ';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กำลังนำเข้า 100 รายการ ($method)...'),
        duration: const Duration(seconds: 3),
      ),
    );

    final elapsed = await provider.importSampleTransactions(
      count: 100,
      useBatch: useBatch,
    );
    if (!context.mounted) return;

    final result = await provider.compareBalanceMethods();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ผลการนำเข้า 100 รายการ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('วิธี: $method'),
            Text('เวลาที่ใช้: ${_ms(elapsed.inMicroseconds)}'),
            const SizedBox(height: 12),
            Text('เปรียบเทียบยอดคงเหลือ (${result.rowCount} แถว)'),
            Text('• SUM ในฐานข้อมูล (rawQuery): ${_ms(result.sqlMicros)}'),
            Text('• โหลดทุกแถว + วนบวกใน Dart: ${_ms(result.dbToDartMicros)}'),
            Text('• วนบวกจาก list ที่โหลดไว้แล้ว: ${_ms(result.inMemoryMicros)}'),
            const SizedBox(height: 8),
            Text(
              'ผลรวมเท่ากัน: '
              '${(result.sqlBalance - result.dartBalance).abs() < 0.01 ? 'ใช่' : 'ต่างกัน'} '
              '(${result.sqlBalance.toStringAsFixed(2)} บาท)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  static String _ms(int micros) => '${(micros / 1000).toStringAsFixed(2)} ms';
}