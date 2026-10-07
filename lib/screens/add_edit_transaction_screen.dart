import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';

// หน้าฟอร์มสำหรับเพิ่มและแก้ไขรายการ (รับข้อมูลมาจากหน้าจอรายการด้วย Navigator)
class AddEditTransactionScreen extends StatefulWidget {
  // ส่ง transaction มาด้วย = โหมดแก้ไข, ไม่ส่ง = โหมดเพิ่มใหม่
  final MyTransaction? transaction;

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController; // ข้อ 1: รายละเอียด (note)
  late DateTime _date;
  late TransactionType _type;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _titleController = TextEditingController(text: tx?.title ?? '');
    _amountController = TextEditingController(
      text: tx == null ? '' : tx.amount.toString(),
    );
    _noteController = TextEditingController(text: tx?.note ?? '');
    _date = tx?.date ?? DateTime.now();
    _type = tx?.type ?? TransactionType.expense;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final title = _titleController.text.trim();
    final amount = double.parse(_amountController.text);
    final note = _noteController.text.trim();

    if (_isEditing) {
      // โหมดแก้ไข -> เรียก updateTransaction
      await provider.updateTransaction(
        widget.transaction!.id!,
        MyTransaction(
          id: widget.transaction!.id,
          title: title,
          amount: amount,
          date: _date,
          type: _type,
          note: note.isEmpty ? null : note,
        ),
      );
    } else {
      // โหมดเพิ่มใหม่ -> เรียก addTransaction
      await provider.addTransaction(
        title,
        amount,
        _date,
        _type,
        note: note.isEmpty ? null : note,
      );
    }

    if (mounted) {
      Navigator.pop(context); // กลับไปหน้าจอรายการ แล้วรายการจะถูกแสดงใหม่ทันที
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการใหม่'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่อรายการ',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'กรุณากรอกชื่อรายการ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'จำนวนเงิน (บาท)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกจำนวนเงิน';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null) return 'จำนวนเงินไม่ถูกต้อง';
                if (amount <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'รายละเอียด (note)',
                hintText: 'บันทึกรายละเอียดของรายการนี้',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('รายรับ'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('รายจ่าย'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'บันทึกการแก้ไข' : 'บันทึกรายการ'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}