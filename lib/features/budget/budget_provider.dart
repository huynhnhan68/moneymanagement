import 'package:flutter/material.dart';
import '../../data/datasources/local/database_helper.dart';

class BudgetProvider extends ChangeNotifier {
  String? _currentUserId;
  double? _currentBudget;

  double? get currentBudget => _currentBudget;

  Future<void> setCurrentUser(String? userId) async {
    _currentUserId = userId;
    await loadCurrentMonthBudget();
  }

  Future<void> loadCurrentMonthBudget() async {
    if (_currentUserId == null) {
      _currentBudget = null;
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    _currentBudget = await DatabaseHelper.instance.getBudgetAmount(
      month: now.month,
      year: now.year,
      userId: _currentUserId,
    );
    notifyListeners();
  }

  Future<void> setBudgetForCurrentMonth(double amount) async {
    if (_currentUserId == null) return;
    final now = DateTime.now();
    await DatabaseHelper.instance.upsertBudget(
      month: now.month,
      year: now.year,
      amount: amount,
      userId: _currentUserId,
    );
    _currentBudget = amount;
    notifyListeners();
  }
}
