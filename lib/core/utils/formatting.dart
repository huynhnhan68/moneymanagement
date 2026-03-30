import 'package:intl/intl.dart';

class Formatting {
  // Hàm định dạng tiền tệ Việt Nam
  static String formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return format.format(amount);
  }

  // Hàm định dạng ngày tháng (dd/MM/yyyy)
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}