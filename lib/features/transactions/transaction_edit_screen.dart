import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';

class TransactionEditScreen extends StatefulWidget {
  final TransactionModel transaction;
  const TransactionEditScreen({super.key, required this.transaction});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _categoryCtrl;
  late bool _isExpense;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.transaction.title);
    _amountCtrl = TextEditingController(
      text: widget.transaction.amount.toString(),
    );
    _categoryCtrl = TextEditingController(text: widget.transaction.category);
    _isExpense = widget.transaction.isExpense;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final category = _categoryCtrl.text.trim();
    if (title.isEmpty || amount <= 0 || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin hợp lệ')),
      );
      return;
    }
    final updated = TransactionModel(
      id: widget.transaction.id,
      title: title,
      amount: amount,
      date: widget.transaction.date,
      category: category,
      isExpense: _isExpense,
      userId: widget.transaction.userId,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa giao dịch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
            ),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền'),
            ),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Danh mục'),
            ),
            SwitchListTile(
              title: const Text('Là chi tiêu'),
              value: _isExpense,
              onChanged: (v) => setState(() => _isExpense = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}
