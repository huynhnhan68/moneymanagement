import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../home/main_screen.dart';
import 'auth_provider.dart';

class LockScreen extends StatefulWidget {
  final bool isSetup; // true: Đang tạo PIN mới, false: Đang đăng nhập
  const LockScreen({super.key, this.isSetup = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _storage = const FlutterSecureStorage();
  String _enteredPin = "";
  String _title = "Nhập mã PIN";

  @override
  void initState() {
    super.initState();
    if (widget.isSetup) {
      _title = "Thiết lập mã PIN mới";
    }
  }

  // Xử lý khi nhấn số
  void _onKeyPressed(String value) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += value;
      });

      // Nếu nhập đủ 4 số thì kiểm tra
      if (_enteredPin.length == 4) {
        _handlePinSubmit();
      }
    }
  }

  // Xử lý khi nhấn xóa
  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  // Logic kiểm tra PIN
  Future<void> _handlePinSubmit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (widget.isSetup) {
      // 1. TRƯỜNG HỢP SETUP: Yêu cầu phải đăng nhập, lưu PIN gắn với user hiện tại
      if (auth.user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thiết lập mã PIN'),
          ),
        );
        Navigator.pop(context, false);
        return;
      }
      final key = 'user_pin_${auth.user!.id}';
      await _storage.write(key: key, value: _enteredPin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã tạo mã PIN thành công!")),
      );
      Navigator.pop(context, true); // Trả về true báo thành công
    } else {
      // 2. TRƯỜNG HỢP ĐĂNG NHẬP: Kiểm tra PIN gắn với user hiện tại
      if (auth.user == null) {
        // Không có user -> không thể kiểm tra
        if (!mounted) return;
        setState(() {
          _enteredPin = "";
          _title = "Không có người dùng. Vui lòng đăng nhập.";
        });
        return;
      }
      final key = 'user_pin_${auth.user!.id}';
      String? storedPin = await _storage.read(key: key);

      if (storedPin != null && storedPin == _enteredPin) {
        // Đúng PIN -> Vào MainScreen
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        // Sai PIN hoặc chưa cài -> Thông báo
        setState(() {
          _enteredPin = "";
          _title = "Sai mã PIN. Thử lại!";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // 4 CHẤM TRÒN HIỂN THỊ TRẠNG THÁI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? Colors.white
                        : Colors.white24,
                  ),
                );
              }),
            ),
            const SizedBox(height: 60),

            // BÀN PHÍM SỐ
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        _buildKeyRow(['4', '5', '6']),
        _buildKeyRow(['7', '8', '9']),
        _buildKeyRow(['', '0', 'del']),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 70, height: 70);
          if (key == 'del') {
            return IconButton(
              onPressed: _onDelete,
              icon: const Icon(Icons.backspace_outlined, color: Colors.white),
              iconSize: 30,
            );
          }
          return GestureDetector(
            onTap: () => _onKeyPressed(key),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  key,
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
