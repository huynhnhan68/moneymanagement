import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatting.dart';
import '../transactions/transaction_provider.dart';
import '../../data/models/transaction_model.dart';
import '../transactions/transaction_detail_screen.dart';
import '../auth/auth_provider.dart';
import '../ai_assistant/smart_desk_screen.dart';
import '../ai_assistant/ai_service.dart';
import '../category/category_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedType = 'Tất cả';
  DateTimeRange? _selectedDateRange;
  @override
  void initState() {
    super.initState();
    // Tải dữ liệu khi mở màn hình và set user hiện tại cho TransactionProvider
    Future.microtask(() async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).setCurrentUser(auth.user?.id?.toString());
      await Provider.of<CategoryProvider>(
        context,
        listen: false,
      ).setCurrentUser(auth.user?.id?.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'aiAssist',
        backgroundColor: AppColors.secondary,
        onPressed: () async {
          if (!AIService.isConfigured) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa cấu hình GOOGLE_API_KEY. Chạy app với --dart-define=GOOGLE_API_KEY=your_key')));
            return;
          }
          final aiService = AIService();
          final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
          final expenseCats = categoryProvider.getCategories(isExpense: true).map((c) => c.name).toList();
          final incomeCats = categoryProvider.getCategories(isExpense: false).map((c) => c.name).toList();

          final controller = TextEditingController();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              bool loading = false;
              return StatefulBuilder(builder: (context, setState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Gõ mô tả giao dịch (VN):', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Ví dụ: Mua cafe tại Highlands 45k'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                            ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final text = controller.text.trim();
                                      if (text.isEmpty) return;
                                      setState(() => loading = true);
                                      final res = await aiService.analyzeTransaction(
                                        inputText: text,
                                        expenseCategories: expenseCats,
                                        incomeCategories: incomeCats,
                                      );
                                      setState(() => loading = false);
                                      Navigator.pop(context);
                                      if (res == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI không trả về kết quả.')));
                                        return;
                                      }

                                      // If AI returned an error map, show it
                                      if (res is Map && res.containsKey('error')) {
                                        final err = res['error']?.toString() ?? 'Lỗi AI không xác định';
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                        return;
                                      }

                                      // Try to parse fields from AI result and save automatically
                                      try {
                                        final amountRaw = res['amount'];
                                        double amount;
                                        if (amountRaw is num) {
                                          amount = amountRaw.toDouble();
                                        } else if (amountRaw is String) {
                                          // Remove non-digit characters and parse
                                          final digits = amountRaw.replaceAll(RegExp(r'[^0-9\-\.]'), '');
                                          amount = double.tryParse(digits) ?? 0.0;
                                        } else {
                                          amount = 0.0;
                                        }

                                        final category = (res['category'] ?? res['categoryName'] ?? '').toString();
                                        final note = (res['note'] ?? '').toString();
                                        final dateStr = (res['date'] ?? '').toString();
                                        DateTime date = DateTime.now();
                                        if (dateStr.isNotEmpty) {
                                          final parsedDate = DateTime.tryParse(dateStr);
                                          if (parsedDate != null) date = parsedDate;
                                        }
                                        final typeStr = (res['type'] ?? '').toString().toLowerCase();
                                        final isExpense = typeStr.startsWith('e') || typeStr == 'expense';

                                        final title = note.isNotEmpty ? note : (category.isNotEmpty ? category : (isExpense ? 'Chi tiêu' : 'Thu nhập'));

                                        if (amount <= 0) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI không trích xuất được số tiền hợp lệ.')));
                                        } else {
                                          final txProvider = Provider.of<TransactionProvider>(context, listen: false);
                                          await txProvider.addTransaction(title, amount, date, category.isNotEmpty ? category : title, isExpense);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu: ${Formatting.formatCurrency(amount)}')));

                                          // Show parsed result and offer to open Smart Desk with category
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Kết quả phân tích'),
                                              content: SingleChildScrollView(child: Text(jsonEncode(res))),
                                              actions: [
                                                if (category.isNotEmpty)
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => SmartDeskScreen(categoryName: category),
                                                        ),
                                                      );
                                                    },
                                                    child: const Text('Mở Smart Desk'),
                                                  ),
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                                              ],
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
                                      }
                                    },
                              child: loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Phân tích'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              });
            },
          );
        },
        child: const Icon(Icons.smart_toy),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<TransactionProvider>(
          builder: (context, provider, child) {
            final transactions = provider.transactions;

            // Local filter state (kept in widget state)
            // We'll apply date/type filtering on top of provider results
            List<TransactionModel> filtered = transactions.where((t) {
              // type filter
              if (_selectedType != 'Tất cả') {
                if (_selectedType == 'Thu' && t.isExpense) return false;
                if (_selectedType == 'Chi' && !t.isExpense) return false;
              }
              // date filter
              if (_selectedDateRange != null) {
                final from = _selectedDateRange!.start;
                final to = _selectedDateRange!.end.add(const Duration(days: 1));
                if (t.date.isBefore(from) || t.date.isAfter(to)) return false;
              }
              return true;
            }).toList();

            return CustomScrollView(
              slivers: [
                // Greeting & SmartDesk button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Xin chào, Nhóm 8",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            // Smart Desk button
                            Material(
                              color: Colors.transparent,
                              child: Tooltip(
                                message: 'Smart Desk - Nhập tiền nhanh',
                                child: InkWell(
                                  onTap: () async {
                                    final result = await Navigator.push<Map>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SmartDeskScreen(),
                                      ),
                                    );
                                    if (result != null) {
                                      await Provider.of<TransactionProvider>(
                                        context,
                                        listen: false,
                                      ).loadTransactions();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit_note,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Provider.of<AuthProvider>(context).user?.email ?? 'Guest',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Balance card inside a SliverToBoxAdapter (will scroll away)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildBalanceCard(
                      provider.balance,
                      provider.totalIncome,
                      provider.totalExpense,
                    ),
                  ),
                ),

                // Sticky Search & Filter
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchFilterHeader(
                    minExtent: 70,
                    maxExtent: 120,
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search field
                          TextField(
                            onChanged: (value) {
                              Provider.of<TransactionProvider>(
                                context,
                                listen: false,
                              ).search(value);
                            },
                            decoration: InputDecoration(
                              hintText: "Tìm kiếm chi tiêu, danh mục...",
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Filter chips row
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Date range button
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.textPrimary,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        initialDateRange: _selectedDateRange,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _selectedDateRange = picked;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(_selectedDateRange == null
                                    ? 'Tất cả thời gian'
                                    : '${Formatting.formatDate(_selectedDateRange!.start)} - ${Formatting.formatDate(_selectedDateRange!.end)}'),
                                  ),
                                ),
                                // Type chips
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: const Text('Tất cả'),
                                    selected: _selectedType == 'Tất cả',
                                    onSelected: (_) => setState(() => _selectedType = 'Tất cả'),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: const Text('Thu'),
                                    selected: _selectedType == 'Thu',
                                    onSelected: (_) => setState(() => _selectedType = 'Thu'),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: const Text('Chi'),
                                    selected: _selectedType == 'Chi',
                                    onSelected: (_) => setState(() => _selectedType = 'Chi'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Transaction list grouped by date (each day shows its own header and transactions)
                filtered.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.search_off,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Không tìm thấy giao dịch nào",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : () {
                        // Group transactions by date (date-only)
                        final Map<DateTime, List<TransactionModel>> groups = {};
                        for (var t in filtered) {
                          final d = DateTime(t.date.year, t.date.month, t.date.day);
                          groups.putIfAbsent(d, () => []).add(t);
                        }

                        final List<DateTime> sortedDates = groups.keys.toList()
                          ..sort((a, b) => b.compareTo(a)); // newest first

                        // Build a flat list of widgets: date header + items
                        final List<Widget> children = [];

                        for (final date in sortedDates) {
                          final items = groups[date]!;
                          // compute totals for the day
                          final dayIncome = items.where((e) => !e.isExpense).fold<double>(0, (s, e) => s + e.amount);
                          final dayExpense = items.where((e) => e.isExpense).fold<double>(0, (s, e) => s + e.amount);

                          children.add(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    Formatting.formatDate(date),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      if (dayIncome > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            "+ ${Formatting.formatCurrency(dayIncome)}",
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      if (dayExpense > 0)
                                        Text(
                                          "- ${Formatting.formatCurrency(dayExpense)}",
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          for (final tx in items) {
                            children.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: _buildTransactionItem(context, tx),
                              ),
                            );
                          }
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => children[index],
                            childCount: children.length,
                          ),
                        );
                      }(),
              ],
            );
          },
        ),
      ),
    );
  }

  // WIDGET: HEADER VÀ THANH TÌM KIẾM
  Widget _buildHeader(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final email = auth.user?.email ?? 'Guest';

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Xin chào, Nhóm 8",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // Nút Smart Desk
                  Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Smart Desk - Nhập tiền nhanh',
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push<Map>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SmartDeskScreen(),
                            ),
                          );

                          // Reload danh sách giao dịch sau khi về lại
                          if (result != null) {
                            await Provider.of<TransactionProvider>(
                              context,
                              listen: false,
                            ).loadTransactions();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),

          // --- SEARCH BAR ---
          TextField(
            onChanged: (value) {
              // Gửi từ khóa xuống Provider để lọc danh sách
              Provider.of<TransactionProvider>(
                context,
                listen: false,
              ).search(value);
            },
            decoration: InputDecoration(
              hintText: "Tìm kiếm chi tiêu, danh mục...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: CARD TỔNG QUAN TÀI CHÍNH
  Widget _buildBalanceCard(double balance, double income, double expense) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Tổng số dư hiện tại",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            Formatting.formatCurrency(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeExpenseInfo(
                "Thu nhập",
                income,
                Icons.arrow_downward,
                Colors.greenAccent,
              ),
              _buildIncomeExpenseInfo(
                "Chi tiêu",
                expense,
                Icons.arrow_upward,
                Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseInfo(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              Formatting.formatCurrency(amount),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // WIDGET: ITEM GIAO DỊCH (Hỗ trợ vuốt xóa)
  Widget _buildTransactionItem(
    BuildContext context,
    TransactionModel transaction,
  ) {
    final provider = Provider.of<TransactionProvider>(context);
    final selected = provider.isSelected(transaction.id);

    return GestureDetector(
      onLongPress: () => provider.toggleSelection(transaction.id),
      onTap: () {
        if (provider.selectedCount > 0) {
          provider.toggleSelection(transaction.id);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: transaction),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: transaction.isExpense
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                transaction.isExpense
                    ? FontAwesomeIcons.bagShopping
                    : FontAwesomeIcons.wallet,
                color: transaction.isExpense ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${transaction.category} • ${Formatting.formatDate(transaction.date)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(
                (transaction.isExpense ? "- " : "+ ") +
                    Formatting.formatCurrency(transaction.amount),
                style: TextStyle(
                  color: transaction.isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterHeader extends SliverPersistentHeaderDelegate {
  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget child;

  _SearchFilterHeader({required this.minExtent, required this.maxExtent, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: overlapsContent ? 4 : 0,
      color: Colors.transparent,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
