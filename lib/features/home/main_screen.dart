import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'home_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../settings/export_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình tương ứng với từng Tab
  final List<Widget> _screens = [
    const HomeScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Hiển thị màn hình theo index đang chọn
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.house),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.chartPie),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.gear),
            label: 'Cài đặt',
          ),
        ],
      ),
      // Nút Thêm Giao Dịch và Xuất Báo Cáo ở góc dưới phải (chỉ hiện ở trang chủ)
      floatingActionButton:
          _selectedIndex ==
              0 // Chỉ hiện ở trang chủ
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Nút xuất (nhỏ)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: FloatingActionButton.small(
                    heroTag: 'export_fab',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ExportScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.white,
                    child: const FaIcon(
                      FontAwesomeIcons.fileExport,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                // Nút thêm giao dịch (chính)
                FloatingActionButton(
                  heroTag: 'add_fab',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  child: const FaIcon(
                    FontAwesomeIcons.plus,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
