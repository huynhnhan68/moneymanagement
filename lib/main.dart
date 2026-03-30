import 'package:flutter/material.dart';
import 'features/budget/budget_provider.dart';

import 'package:provider/provider.dart'; // Thư viện quản lý trạng thái
import 'package:google_fonts/google_fonts.dart'; // Thư viện Font chữ

// Import các file trong dự án
import 'core/constants/app_colors.dart';
import 'core/services/notification_service.dart'; // Import Service thông báo mới tạo
import 'features/auth/login_screen.dart';
import 'features/auth/auth_provider.dart';
import 'features/transactions/transaction_provider.dart';
import 'features/category/category_provider.dart';

// Chuyển hàm main thành async để thực hiện các tác vụ khởi tạo
void main() async {
  // 1. Bắt buộc phải có dòng này để đảm bảo Flutter engine đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo Dịch vụ Thông báo (Notification)
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService
      .requestPermissions(); // Xin quyền thông báo (quan trọng cho Android 13+)

  // 4. Khởi tạo AuthProvider và nạp trạng thái đăng nhập từ bộ nhớ
  final authProvider = AuthProvider();
  await authProvider.loadFromStorage();

  // 4b. Khởi tạo CategoryProvider và nạp danh mục cho user hiện tại
  final categoryProvider = CategoryProvider();
  await categoryProvider.setCurrentUser(authProvider.user?.id?.toString());

  // 5. Quyết định màn hình đầu tiên
  // Luôn hiện LoginScreen ở lần khởi động trước khi yêu cầu PIN.
  // Màn LockScreen sẽ chỉ xuất hiện SAU khi user đã đăng nhập (handled trong LoginScreen).
  Widget firstScreen = const LoginScreen();

  // 6. Chạy ứng dụng (thêm AuthProvider vào MultiProvider)
  runApp(
    MultiProvider(
      providers: [
        // Khởi tạo Provider quản lý người dùng (Auth) và giao dịch để dùng cho toàn bộ App
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => categoryProvider),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      // Truyền màn hình đầu tiên đã xác định vào MyApp
      child: MyApp(startScreen: firstScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget startScreen; // Biến lưu màn hình khởi động

  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Finance Tracker',
      debugShowCheckedModeBanner: false, // Tắt chữ DEBUG ở góc phải
      // Cấu hình giao diện chung (Theme)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        textTheme:
            GoogleFonts.robotoTextTheme(), // Sử dụng font Roboto hiện đại
      ),

      // Màn hình trang chủ được quyết định động (Dynamic)
      home: startScreen,
    );
  }
}
