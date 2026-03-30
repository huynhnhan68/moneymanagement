class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final bool isExpense; // true: Chi, false: Thu
  final String? userId; // id của user sở hữu giao dịch

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isExpense,
    this.userId,
  });

  // Chuyển từ Object sang Map (Để lưu vào SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(), // SQLite lưu ngày dưới dạng chuỗi
      'category': category,
      'isExpense': isExpense ? 1 : 0, // SQLite lưu bool: 1 là true, 0 là false
      'user_id': userId,
    };
  }

  // Chuyển từ Map sang Object (Để hiển thị lên UI)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      category: map['category'],
      isExpense: map['isExpense'] == 1,
      userId: map['user_id'] as String?,
    );
  }
}
