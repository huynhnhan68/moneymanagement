import 'dart:convert';
import 'package:http/http.dart' as http; // Dùng thư viện http
import 'package:intl/intl.dart';

class AIService {
  // 🟢 DÁN KEY GROQ CỦA BẠN VÀO ĐÂY (Bắt đầu bằng gsk_...)
  static const String _apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '', // Thay thế bằng key thật khi chạy app
  );

  static bool get isConfigured => _apiKey.startsWith('gsk_');

  Future<Map<String, dynamic>?> analyzeTransaction({
    required String inputText,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    try {
      if (!isConfigured) {
        print('❌ Chưa cấu hình Groq API Key.');
        return null;
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final allCats = (expenseCategories + incomeCategories).join(', ');

      // Cấu hình Request gửi lên Groq
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final body = jsonEncode({
        "model":
            "llama-3.3-70b-versatile", // Dùng model Llama 3 (nhanh và thông minh)
        "messages": [
          {
            "role": "system",
            "content":
                "Bạn là trợ lý tài chính trả về JSON. Hôm nay: $today. Danh mục: [$allCats].",
          },
          {
            "role": "user",
            "content":
                """
            Phân tích: "$inputText"
            Yêu cầu trả về JSON chuẩn (không markdown) với các trường:
            - amount: số tiền (int)
            - category: tên danh mục (string, chọn từ danh sách)
            - note: ghi chú (string)
            - date: ngày (yyyy-MM-dd)
            - type: "expense" hoặc "income"
            Ví dụ output: {"amount": 50000, "category": "Ăn uống", "note": "Phở", "date": "2024-01-01", "type": "expense"}
            """,
          },
        ],
        "response_format": {"type": "json_object"}, // Bắt buộc trả về JSON
      });

      print('🚀 Đang gửi yêu cầu tới Groq...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        // Xử lý dữ liệu trả về
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];

        print('✅ Groq trả lời: $content');

        try {
          return jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          print('❌ Lỗi parse JSON từ Groq: $e');
        }
      } else {
        print('❌ Lỗi API Groq (${response.statusCode}): ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Lỗi kết nối: $e');
      return null;
    }
  }
}
