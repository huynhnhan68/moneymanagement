import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../../core/constants/app_colors.dart';
import 'transaction_provider.dart'; // Import Provider của mình
import '../auth/auth_provider.dart';
import '../category/category_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isExpense = true;
  String? _selectedCategory;

  final List<String> _expenseCategories = [
    'Ăn uống',
    'Di chuyển',
    'Mua sắm',
    'Giải trí',
    'Hóa đơn',
  ];
  final List<String> _incomeCategories = [
    'Lương',
    'Thưởng',
    'Bán đồ',
    'Tiền lãi',
  ];

  // initState removed: do not access Provider here (may not be in widget tree yet)

  Future<void> _presentDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // --- HÀM LƯU DỮ LIỆU CHÍNH ---
  void _submitData() {
    final enteredAmount = double.tryParse(_amountController.text);
    final enteredNote = _noteController.text;

    // Validate: Kiểm tra nhập liệu
    if (enteredAmount == null ||
        enteredAmount <= 0 ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ và chọn danh mục!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Yêu cầu đăng nhập trước khi thêm giao dịch
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thêm giao dịch')),
      );
      return;
    }

    // GỌI PROVIDER ĐỂ LƯU VÀO DATABASE [cite: 88, 102]
    // listen: false vì ta chỉ gọi hàm, không cần vẽ lại màn hình này
    Provider.of<TransactionProvider>(context, listen: false).addTransaction(
      enteredNote.isEmpty
          ? _selectedCategory!
          : enteredNote, // Nếu không ghi chú thì lấy tên danh mục
      enteredAmount,
      _selectedDate,
      _selectedCategory!,
      _isExpense,
    );

    // Thông báo thành công và đóng màn hình
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã thêm giao dịch thành công!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  void _showAddCategoryDialog() {
    final TextEditingController ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Thêm danh mục mới'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Tên danh mục'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                final provider = Provider.of<CategoryProvider>(context, listen: false);
                await provider.addCategory(name: name);
                setState(() {
                  _selectedCategory = name;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Thêm'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoryProvider>(context);
    final List<String> categoriesFromProvider = provider.getCategories(isExpense: _isExpense).map((c) => c.name).toList();

    final List<String> categories = categoriesFromProvider.isNotEmpty
      ? categoriesFromProvider
      : (_isExpense ? _expenseCategories : _incomeCategories);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Thêm Giao Dịch",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOGGLE SWITCH
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildTabButton("Chi tiêu", true),
                  _buildTabButton("Thu nhập", false),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. AMOUNT INPUT
            const Text("Số tiền", style: TextStyle(color: Colors.grey)),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: _isExpense ? AppColors.error : AppColors.primary,
              ),
              decoration: InputDecoration(
                hintText: "0",
                suffixText: "đ",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[300]),
              ),
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 20),

            // 3. CATEGORY
            const Text(
              "Danh mục",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                    ),
                    hint: const Text("Chọn danh mục"),
                    initialValue: _selectedCategory,
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(
                              _isExpense
                                  ? FontAwesomeIcons.bagShopping
                                  : FontAwesomeIcons.wallet,
                              size: 18,
                              color: _isExpense ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 10),
                            Text(cat),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Button to add new category
                IconButton(
                  tooltip: 'Thêm danh mục',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // 4. DATE PICKER
            const Text(
              "Ngày giao dịch",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _presentDatePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. NOTE INPUT
            const Text(
              "Ghi chú",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: "Ví dụ: Ăn trưa",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 6. SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "LƯU GIAO DỊCH",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isExpenseTab) {
    bool isActive = _isExpense == isExpenseTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpense = isExpenseTab;
            _selectedCategory = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? (isExpenseTab ? AppColors.error : AppColors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
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
