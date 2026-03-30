import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../transactions/transaction_provider.dart';
import '../home/main_screen.dart';
import 'lock_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.register(_emailCtrl.text.trim(), _passCtrl.text);
      if (auth.isAuthenticated) {
        // Cập nhật TransactionProvider
        Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).setCurrentUser(auth.user?.id?.toString());

        // Yêu cầu thiết lập PIN ngay sau đăng ký (bắt buộc hoặc cho phép bỏ qua)
        bool pinCreated = false;
        while (!pinCreated) {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const LockScreen(isSetup: true)),
          );
          if (res == true) {
            pinCreated = true;
            break;
          }

          // Nếu user hủy, hỏi có muốn tạo ngay hay bỏ qua
          final doCreate = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Chưa thiết lập mã PIN'),
                content: const Text(
                  'Bạn chưa tạo mã PIN cho tài khoản này. Bạn muốn tạo ngay bây giờ không?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Bỏ qua'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Tạo ngay'),
                  ),
                ],
              );
            },
          );

          if (doCreate != true) {
            // Nếu chọn bỏ qua hoặc đóng dialog -> thoát vòng lặp
            break;
          }
          // Nếu chọn 'Tạo ngay' -> lặp lại để mở LockScreen lần nữa
        }

        // Sau cùng chuyển sang MainScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Vui lòng nhập mật khẩu xác nhận'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const CircularProgressIndicator()
                    : const Text('Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
