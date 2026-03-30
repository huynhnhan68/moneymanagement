import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_provider.dart';
import '../transactions/transaction_provider.dart';
import 'register_screen.dart';
import 'lock_screen.dart';
import '../home/main_screen.dart';
import '../budget/budget_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (auth.isAuthenticated) {
        // Cập nhật TransactionProvider để tải dữ liệu cho user hiện tại
        Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).setCurrentUser(auth.user?.id?.toString());
        Provider.of<BudgetProvider>(context, listen: false)
            .setCurrentUser(auth.user?.id?.toString());

        // Nếu user đã tạo PIN -> yêu cầu nhập PIN ngay sau login
        final storage = const FlutterSecureStorage();
        final pin = await storage.read(key: 'user_pin_${auth.user?.id}');
        if (pin != null) {
          // Chuyển sang màn nhập PIN (LockScreen). LockScreen sẽ chuyển tiếp vào MainScreen nếu đúng PIN
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LockScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
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
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const CircularProgressIndicator()
                    : const Text('Đăng nhập'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
