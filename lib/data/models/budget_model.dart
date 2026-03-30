class BudgetModel {
  final int? id;
  final int month;
  final int year;
  final double amount;
  final String? userId;

  BudgetModel({
    this.id,
    required this.month,
    required this.year,
    required this.amount,
    this.userId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'month': month,
        'year': year,
        'amount': amount,
        'user_id': userId,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      month: map['month'] as int,
      year: map['year'] as int,
      amount: (map['amount'] as num).toDouble(),
      userId: map['user_id'] as String?,
    );
  }
}
