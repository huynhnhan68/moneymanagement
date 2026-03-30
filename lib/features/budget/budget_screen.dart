import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'budget_provider.dart';
import '../transactions/transaction_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final budget = budgetProvider.currentBudget;

    // tổng chi tháng hiện tại (dựa trên transactions đã load)
    final now = DateTime.now();
    final spent = txProvider.transactions
        .where((t) => t.isExpense && t.date.month == now.month && t.date.year == now.year)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách tháng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đã chi tháng này: ${spent.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text('Ngân sách hiện tại: ${budget?.toStringAsFixed(0) ?? "Chưa đặt"}'),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nhập ngân sách tháng (VD: 5000000)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(_ctrl.text.trim());
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Số tiền không hợp lệ')),
                  );
                  return;
                }
                await context.read<BudgetProvider>().setBudgetForCurrentMonth(value);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu ngân sách')),
                );
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
