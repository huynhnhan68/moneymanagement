import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/category_model.dart';

class CategoryProvider with ChangeNotifier {
  final List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => List.unmodifiable(_categories);

  String? _currentUserId;

  // Default protected category IDs (do not allow edit/delete)
  static const List<String> _defaultIds = [
    'E1','E2','E3','E4','E5','E6','E7','E8','E9','E10','E11',
    'I1','I2','I3',
  ];
  final Set<String> _defaultIdSet = Set<String>.from(_defaultIds);

  bool isDefaultCategory(String id) => _defaultIdSet.contains(id);

  Future<void> setCurrentUser(String? userId) async {
    _currentUserId = userId;
    await loadCategories(userId: _currentUserId);
  }

  Future<void> loadCategories({String? userId}) async {
    final rows = await DatabaseHelper.instance.getAllCategories(userId: userId);
    _categories.clear();
    for (final r in rows) {
      // Map<String, dynamic>
      final map = Map<String, dynamic>.from(r);
      _categories.add(CategoryModel.fromMap(map));
    }
    notifyListeners();
  }

  /// Return categories, optionally filtering by expense/income.
  /// We determine expense/income by ID prefix: 'E' = expense (chi), 'I' = income (thu).
  List<CategoryModel> getCategories({bool? isExpense}) {
    if (isExpense == null) return List.unmodifiable(_categories);
    if (isExpense) {
      return _categories.where((c) => c.id.toUpperCase().startsWith('E')).toList();
    } else {
      return _categories.where((c) => c.id.toUpperCase().startsWith('I')).toList();
    }
  }

  Future<void> addCategory({
    required String name,
  }) async {
    final id = const Uuid().v4();
    final model = CategoryModel(
      id: id,
      name: name,
    );
    await DatabaseHelper.instance.insertCategory(model.toMap());
    _categories.add(model);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    if (isDefaultCategory(id)) return; // protect defaults
    await DatabaseHelper.instance.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel updated) async {
    if (isDefaultCategory(updated.id)) return; // do not allow editing defaults
    await DatabaseHelper.instance.updateCategory(updated.id, updated.toMap());
    final idx = _categories.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      _categories[idx] = updated;
      notifyListeners();
    }
  }
}
