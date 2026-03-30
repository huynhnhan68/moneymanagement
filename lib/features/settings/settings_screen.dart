import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../auth/auth_provider.dart';
import '../transactions/transaction_provider.dart';
import '../budget/budget_provider.dart';

import '../budget/budget_screen.dart';
import '../auth/lock_screen.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = const FlutterSecureStorage();

  // Trạng thái của các chức năng
  bool _isPinEnabled = false;
  bool _isNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  // Kiểm tra trạng thái hiện tại khi mở màn hình
  Future<void> _checkStatus() async {
    // Kiểm tra xem có PIN lưu trong máy không, theo user hiện tại
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      setState(() {
        _isPinEnabled = false;
      });
      return;
    }
    String? pin = await _storage.read(key: 'user_pin_${auth.user!.id}');

    setState(() {
      _isPinEnabled = pin != null;
      // Lưu ý: Với thông báo, trong phạm vi đồ án đơn giản ta tạm thời không lưu trạng thái bật/tắt vào ổ cứng
      // Nếu muốn kỹ hơn, bạn có thể dùng SharedPreferences để lưu biến _isNotificationEnabled
    });
  }

  // LOGIC 1: BẬT/TẮT THÔNG BÁO
  void _toggleNotification(bool value) async {
    setState(() {
      _isNotificationEnabled = value;
    });

    if (value) {
      // NẾU BẬT -> Lên lịch nhắc nhở lúc 21:00
      await NotificationService().scheduleDailyNotification(
        id: 0,
        title: "Đã đến giờ ghi sổ!",
        body: "Bạn đã chi tiêu gì hôm nay? Hãy ghi lại ngay nhé.",
        hour: 21, // Giờ nhắc (21 giờ tối)
        minute: 00,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã bật nhắc nhở hằng ngày lúc 21:00")),
        );
      }
    } else {
      // NẾU TẮT -> Hủy toàn bộ thông báo
      await NotificationService().cancelAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Đã tắt nhắc nhở")));
      }
    }
  }

  // LOGIC 2: BẬT/TẮT MÃ PIN
  Future<void> _togglePin(bool value) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      // Yêu cầu đăng nhập trước khi bật PIN
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để bật mã PIN')),
        );
      }
      return;
    }

    final key = 'user_pin_${auth.user!.id}';

    if (value) {
      // Nếu BẬT -> Mở màn hình tạo PIN
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LockScreen(isSetup: true)),
      );
      // Nếu tạo PIN thành công (trả về true) thì cập nhật UI
      if (result == true) {
        setState(() => _isPinEnabled = true);
      }
    } else {
      // Nếu TẮT -> Xóa PIN khỏi bộ nhớ an toàn cho user hiện tại
      await _storage.delete(key: key);
      setState(() => _isPinEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Đã tắt bảo mật PIN")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Cài Đặt",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- PHẦN 1: TIỆN ÍCH (THÔNG BÁO + NGÂN SÁCH) ---
          const Text(
            "Tiện ích",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Nhắc nhở hằng ngày"),
                  subtitle: const Text("Thông báo lúc 21:00"),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.orange,
                    ),
                  ),
                  value: _isNotificationEnabled,
                  onChanged: _toggleNotification, // Gọi hàm xử lý thông báo
                  activeThumbColor: AppColors.primary,
                ),

                const Divider(height: 1),

                // ✅ THÊM MỤC NGÂN SÁCH THÁNG
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text("Ngân sách tháng"),
                  subtitle: const Text("Đặt hạn mức chi tiêu & cảnh báo vượt"),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BudgetScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // --- PHẦN 2: BẢO MẬT (PIN) ---
          const Text(
            "Bảo mật",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Khóa ứng dụng bằng PIN"),
                  subtitle: const Text("Bảo vệ dữ liệu riêng tư"),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock, color: Colors.blue),
                  ),
                  value: _isPinEnabled,
                  onChanged: _togglePin, // Gọi hàm xử lý PIN
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // --- PHẦN 3: THÔNG TIN ỨNG DỤNG ---
          const Text(
            "Thông tin ứng dụng",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.circleInfo,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: const Text("Phiên bản"),
              trailing: const Text(
                "1.0.0",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Hiển thị màn chào lại (Reset first-run)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.repeat,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: const Text("Hiển thị lại màn chào (Login)"),
              subtitle: const Text(
                "Cho phép hiển thị màn Đăng nhập/Đăng ký lần đầu khi khởi động",
              ),
              onTap: () async {
                await _storage.delete(key: 'seen_welcome');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Sẽ hiện màn chào lần tiếp theo bạn mở app'),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),

          // Nút đăng xuất
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.rightFromBracket,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              title: const Text("Đăng xuất"),
              onTap: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.logout();

                // Clear transactions for previous user
                Provider.of<TransactionProvider>(context, listen: false)
                    .setCurrentUser(null);

                // ✅ THÊM DÒNG CLEAR BUDGET CHO USER CŨ
                Provider.of<BudgetProvider>(context, listen: false)
                    .setCurrentUser(null);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã đăng xuất")),
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
