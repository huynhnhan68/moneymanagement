import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider để lấy dữ liệu
import '../../core/constants/app_colors.dart';
import '../../data/models/transaction_model.dart';
import '../../core/utils/formatting.dart';
import '../transactions/transaction_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedTab = 1; // Mặc định chọn "Tháng này" (1) cho dễ nhìn

  @override
  Widget build(BuildContext context) {
    // 1. Lắng nghe dữ liệu từ Provider
    final provider = Provider.of<TransactionProvider>(context);
    final allTransactions = provider.transactions;

    // 2. Lọc danh sách theo Tab (Tuần hoặc Tháng) và chỉ lấy CHI TIÊU
    List<TransactionModel> filteredList = _filterTransactions(allTransactions, _selectedTab);
    
    // Tính tổng chi trong khoảng thời gian này
    double totalExpenseInPeriod = filteredList.fold(0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Thống Kê Chi Tiêu", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: filteredList.isEmpty 
      ? const Center(child: Text("Chưa có dữ liệu chi tiêu trong khoảng thời gian này.")) 
      : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // THANH CHUYỂN ĐỔI (TOGGLE)
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  _buildTabButton("Tuần này", 0),
                  _buildTabButton("Tháng này", 1),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            Text("Tổng chi: ${Formatting.formatCurrency(totalExpenseInPeriod)}", 
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),

            // --- BIỂU ĐỒ TRÒN ---
            const Text("Cơ cấu danh mục", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 250, // Tăng chiều cao để chứa chú thích
              child: _buildPieChart(filteredList, totalExpenseInPeriod),
            ),
            const SizedBox(height: 40),

            // --- BIỂU ĐỒ CỘT ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Biến động theo ngày", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _buildBarChart(filteredList),
            ),
          ],
        ),
      ),
    );
  }

  // LOGIC 1: LỌC DATA THEO THỜI GIAN
  List<TransactionModel> _filterTransactions(List<TransactionModel> list, int mode) {
    final now = DateTime.now();
    // Chỉ lấy Chi tiêu (isExpense == true)
    final expenses = list.where((element) => element.isExpense).toList();

    if (mode == 0) { // Tuần này
      // Tìm ngày đầu tuần (Thứ 2)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      return expenses.where((t) => t.date.isAfter(startOfDate) || t.date.isAtSameMomentAs(startOfDate)).toList();
    } else { // Tháng này
      return expenses.where((t) => t.date.month == now.month && t.date.year == now.year).toList();
    }
  }

  // LOGIC 2: XÂY DỰNG BIỂU ĐỒ TRÒN
  Widget _buildPieChart(List<TransactionModel> list, double total) {
    // Gom nhóm theo danh mục
    Map<String, double> categoryTotals = {};
    for (var item in list) {
      categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + item.amount;
    }

    // Chuyển Map thành List<PieChartSectionData>
    List<PieChartSectionData> sections = [];
    int index = 0;
    // Bảng màu cho các danh mục
    final List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal];

    categoryTotals.forEach((category, amount) {
      final percentage = (amount / total * 100);
      sections.add(
        PieChartSectionData(
          color: colors[index % colors.length],
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      index++;
    });

    return Row(
      children: [
        // Phần hình tròn
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        // Phần chú thích (Legend)
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: categoryTotals.keys.toList().asMap().entries.map((entry) {
              int idx = entry.key;
              String catName = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: colors[idx % colors.length]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(catName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // LOGIC 3: XÂY DỰNG BIỂU ĐỒ CỘT (Theo thứ trong tuần)
  Widget _buildBarChart(List<TransactionModel> list) {
    // Mảng chứa tổng tiền 7 ngày (0: Thứ 2 ... 6: CN)
    List<double> weeklyTotals = List.filled(7, 0.0);
    double maxVal = 0;

    for (var item in list) {
      // item.date.weekday trả về 1 (Thứ 2) -> 7 (CN)
      // Ta cần index 0 -> 6
      int index = item.date.weekday - 1; 
      weeklyTotals[index] += item.amount;
      if (weeklyTotals[index] > maxVal) maxVal = weeklyTotals[index];
    }

    // Tạo BarGroups
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 7; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeklyTotals[i],
              color: weeklyTotals[i] > 0 ? AppColors.primary : Colors.grey[300],
              width: 12,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal * 1.1, // Cột nền cao hơn giá trị max 1 xíu
                color: Colors.grey[100],
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.1,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(days[value.toInt()], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }

  // Helper: Nút chuyển Tab
  Widget _buildTabButton(String label, int index) {
    bool isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}