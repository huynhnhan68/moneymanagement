import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatting.dart';
import 'transaction_provider.dart';
import '../../data/models/transaction_model.dart';
import 'transaction_edit_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.of(context)
                  .push<TransactionModel?>(
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionEditScreen(transaction: transaction),
                    ),
                  );
              if (updated != null) {
                await provider.updateTransaction(updated);
                Navigator.of(context).pop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text('Xác nhận'),
                    content: const Text('Bạn có muốn xóa giao dịch này không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Xóa'),
                      ),
                    ],
                  );
                },
              );
              if (ok == true) {
                await provider.deleteTransaction(transaction.id);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '${transaction.category} • ${Formatting.formatDate(transaction.date)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              Formatting.formatCurrency(transaction.amount),
              style: TextStyle(
                color: transaction.isExpense ? Colors.red : Colors.green,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
