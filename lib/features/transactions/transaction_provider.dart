import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../core/services/notification_service.dart';

class TransactionProvider with ChangeNotifier {
  // Danh sách gốc lấy từ Database
  List<TransactionModel> _transactions = [];

  // Từ khóa tìm kiếm hiện tại
  String _searchText = "";

  // Biến lưu tổng tiền
  double _totalIncome = 0;
  double _totalExpense = 0;

  // --- LOGIC TÌM KIẾM & LỌC DỮ LIỆU ---
  // UI sẽ gọi getter này để hiển thị.
  // Nếu _searchText rỗng -> Trả về toàn bộ.
  // Nếu có từ khóa -> Lọc theo Tên hoặc Danh mục.
  List<TransactionModel> get transactions {
    if (_searchText.isEmpty) {
      return _transactions;
    } else {
      return _transactions.where((t) {
        final keyword = _searchText.toLowerCase();
        final title = t.title.toLowerCase();
        final category = t.category.toLowerCase();
        // Tìm kiếm theo tên giao dịch HOẶC tên danh mục
        return title.contains(keyword) || category.contains(keyword);
      }).toList();
    }
  }

  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _totalIncome - _totalExpense;

  // --- HÀM GỌI TỪ UI ---

  // 1. Hàm nhận từ khóa tìm kiếm từ UI
  void search(String query) {
    _searchText = query;
    notifyListeners(); // Báo cho UI vẽ lại danh sách kết quả
  }

  String? _currentUserId;

  // Thiết lập user hiện tại cho Provider (gọi khi login/logout)
  Future<void> setCurrentUser(String? userId) async {
    _currentUserId = userId;
    if (userId == null) {
      _transactions = [];
      _totalIncome = 0;
      _totalExpense = 0;
      notifyListeners();
    } else {
      await loadTransactions(userId: userId);
    }
  }

  // 2. Tải dữ liệu từ SQLite (lọc theo user hiện tại nếu có)
  Future<void> loadTransactions({String? userId}) async {
    if (userId != null) _currentUserId = userId;
    _transactions = await DatabaseHelper.instance.getAllTransactions(
      userId: _currentUserId,
    );
    await _calculateTotals();
    notifyListeners();
  }

  // 3. Thêm giao dịch mới
  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    String category,
    bool isExpense,
  ) async {
    final newTransaction = TransactionModel(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      date: date,
      category: category,
      isExpense: isExpense,
      userId: _currentUserId,
    );

    await DatabaseHelper.instance.insertTransaction(newTransaction);
    await loadTransactions(); // Tải lại danh sách sau khi thêm
    await _checkBudgetAndNotify();
  }

  // 4. Xóa giao dịch
  Future<void> deleteTransaction(String id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadTransactions();
  }

  // 4b. Xóa nhiều giao dịch cùng lúc
  Future<void> deleteTransactions(List<String> ids) async {
    await DatabaseHelper.instance.deleteTransactions(ids);
    _selected.clear();
    await loadTransactions();
  }

  // 5. Cập nhật giao dịch
  Future<void> updateTransaction(TransactionModel transaction) async {
    await DatabaseHelper.instance.updateTransaction(transaction);
    await loadTransactions();
    await _checkBudgetAndNotify();
  }

  // --- SELECTION (Chọn nhiều để xóa) ---
  final Set<String> _selected = {};

  List<String> get selectedIds => _selected.toList();
  int get selectedCount => _selected.length;
  bool isSelected(String id) => _selected.contains(id);

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isNotEmpty) {
      _selected.clear();
      notifyListeners();
    }
  }

  // Hàm phụ trợ: Tính tổng thu chi
  Future<void> _calculateTotals() async {
    final totals = await DatabaseHelper.instance.getTotalIncomeExpense(
      userId: _currentUserId,
    );
    _totalIncome = totals['income'] ?? 0;
    _totalExpense = totals['expense'] ?? 0;
  }

  // Lấy danh sách danh mục (không trùng) theo loại (expense/income/both)
  List<String> getCategories({bool? isExpense}) {
    final filtered = isExpense == null
        ? _transactions
        : _transactions.where((t) => t.isExpense == isExpense).toList();
    final set = <String>{};
    for (final t in filtered) {
      final c = t.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  double _spentThisMonth() {
    final now = DateTime.now();
    double sum = 0;
    for (final t in _transactions) {
      if (t.isExpense && t.date.month == now.month && t.date.year == now.year) {
        sum += t.amount;
      }
    }
    return sum;
  }

  Future<void> _checkBudgetAndNotify() async {
    if (_currentUserId == null) return;

    final now = DateTime.now();
    final budget = await DatabaseHelper.instance.getBudgetAmount(
      month: now.month,
      year: now.year,
      userId: _currentUserId,
    );

    if (budget == null || budget <= 0) return;

    final spent = _spentThisMonth();
    if (spent >= budget) {
      await NotificationService().showBudgetExceeded(
        budget: budget,
        spent: spent,
      );
    }
  }
}
