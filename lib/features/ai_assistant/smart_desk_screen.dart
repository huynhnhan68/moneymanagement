import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/app_colors.dart';
import '../transactions/transaction_provider.dart';
import '../category/category_provider.dart';

class SmartDeskScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final Color? categoryColor;

  const SmartDeskScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
  });

  @override
  State<SmartDeskScreen> createState() => _SmartDeskScreenState();
}

class _SmartDeskScreenState extends State<SmartDeskScreen> {
  // GIAI ĐOẠN 2: DATA STATE
  double currentAmount = 0;
  String? currentCategory = '';
  String? currentCategoryName = '';
  Color? currentCategoryColor = AppColors.primary;
  DateTime selectedDate = DateTime.now();
  List<double> historyStack = [];
  // Track dropped money images for visual pile around the wallet
  final List<String> droppedMoneyImages = [];
  double _walletScale = 1.0;

  // Track amounts by category separately
  // Map<categoryId, {amount: double, categoryName: string, color: Color}>
  final Map<String, Map<String, dynamic>> categoryAmounts = {};
  
  // Track selected money denomination for +/- counter
  String? selectedMoneyId;
  int selectedMoneyCount = 0;

  // Audio player
  late AudioPlayer _audioPlayer;

  // Danh sách các mệnh giá tiền Việt Nam
  final List<Map<String, dynamic>> moneyDenominations = [
    {'value': 1000, 'label': '1K', 'image': 'assets/images/money/anh-tien-1k.jpeg', 'color': Color(0xFF1976D2)},
    {'value': 2000, 'label': '2K', 'image': 'assets/images/money/anh-tien-2k.jpg', 'color': Color(0xFF1565C0)},
    {'value': 5000, 'label': '5K', 'image': 'assets/images/money/anh-tien-5k.jpg', 'color': Color(0xFF0D47A1)},
    {'value': 10000, 'label': '10K', 'image': 'assets/images/money/anh-tien-10k.jpg', 'color': Color(0xFF6A1B9A)},
    {'value': 20000, 'label': '20K', 'image': 'assets/images/money/anh-tien-20k.jpg', 'color': Color(0xFF4A148C)},
    {'value': 50000, 'label': '50K', 'image': 'assets/images/money/anh-tien-50k.jpg', 'color': Color(0xFF00897B)},
    {'value': 100000, 'label': '100K', 'image': 'assets/images/money/anh-tien-100k.jpg', 'color': Color(0xFF004D40)},
    {'value': 200000, 'label': '200K', 'image': 'assets/images/money/anh-tien-200k.jpg', 'color': Color(0xFF7B1FA2)},
    {'value': 500000, 'label': '500K', 'image': 'assets/images/money/anh-tien-500k.jpg', 'color': Color(0xFF4A148C)},
  ];

  final List<Map<String, dynamic>> _Categories = [
    {'name': 'Ăn uống', 'color': Color(0xFFFF6B6B), 'icon': Icons.restaurant},
    {'name': 'Di chuyển', 'color': Color(0xFF4ECDC4), 'icon': Icons.directions_car},
    {'name': 'Mua sắm', 'color': Color(0xFFFFD93D), 'icon': Icons.shopping_cart},
    {'name': 'Giải trí', 'color': Color(0xFF6C5CE7), 'icon': Icons.movie},
    {'name': 'Hóa đơn', 'color': Color(0xFF00B894), 'icon': Icons.receipt},
  ];

  // Danh mục (Categories)
  // Categories will be loaded from CategoryProvider (transaction categories are authoritative)

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // If this screen is opened with a category (from other screens), prefer the category name
    currentCategory = widget.categoryName ?? widget.categoryId ?? '';
    currentCategoryName = widget.categoryName ?? '';
    currentCategoryColor = widget.categoryColor ?? AppColors.primary;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // GIAI ĐOẠN 2 & 3: Xử lý khi thả tiền vào ví
  void _onMoneyAccepted(double amount) {
    HapticFeedback.mediumImpact();
    setState(() {
      currentAmount += amount;
      historyStack.add(amount);
      _walletScale = 1.06;
      
      // Track amount for current category - using categoryName as key for consistency
      if (currentCategoryName != null && currentCategoryName!.isNotEmpty) {
        final key = currentCategoryName!; // Use name as key to ensure consistency
        if (!categoryAmounts.containsKey(key)) {
          categoryAmounts[key] = {
            'amount': 0.0,
            'categoryName': currentCategoryName,
            'color': currentCategoryColor,
          };
        }
        categoryAmounts[key]!['amount'] += amount;
      }
    });
    // reset scale for a bouncy effect
    Future.delayed(Duration(milliseconds: 180), () {
      if (mounted) setState(() => _walletScale = 1.0);
    });
    _playSound('coin_drop');
  }

  // Xử lý khi thả danh mục vào ví
  void _onCategoryAccepted(String categoryId, String categoryName, Color color) {
    HapticFeedback.lightImpact();
    setState(() {
      currentCategory = categoryName; // Store by name for consistency
      currentCategoryName = categoryName;
      currentCategoryColor = color;
    });
    _playSound('paper_rustle');
    
    // Show snackbar to confirm category selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chọn danh mục: $categoryName'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // GIAI ĐOẠN 3: Undo mechanism - quay lại lần nhập tiền trước
  void _undo() {
    if (historyStack.isNotEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        double lastAmount = historyStack.removeLast();
        currentAmount -= lastAmount;
        
        // Remove from current category using category name
        if (currentCategoryName != null && currentCategoryName!.isNotEmpty) {
          final key = currentCategoryName!;
          if (categoryAmounts.containsKey(key)) {
            categoryAmounts[key]!['amount'] -= lastAmount;
            // Remove category if amount becomes 0
            if (categoryAmounts[key]!['amount'] <= 0) {
              categoryAmounts.remove(key);
            }
          }
        }
        
        // Remove the last image when undoing
        if (droppedMoneyImages.isNotEmpty) {
          droppedMoneyImages.removeLast();
        }
      });
    }
  }

  // Reset về 0
  void _reset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận'),
        content: Text('Bạn có chắc muốn xóa tất cả?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                currentAmount = 0;
                historyStack.clear();
                droppedMoneyImages.clear();
                categoryAmounts.clear();
                selectedMoneyId = null;
                selectedMoneyCount = 0;
              });
              Navigator.pop(context);
            },
            child: Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // GIAI ĐOẠN 3: Fine-tuner - mở popup nhập số
  void _openNumPad() {
    final TextEditingController controller =
        TextEditingController(text: currentAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa số tiền'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Số tiền (VND)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text) ?? currentAmount;
              setState(() {
                currentAmount = newAmount;
                historyStack.clear();
                historyStack.add(newAmount);
                // If user manually inputs a single value, clear decorative images
                droppedMoneyImages.clear();
                // Clear category amounts when manually editing
                categoryAmounts.clear();
                selectedMoneyId = null;
                selectedMoneyCount = 0;
              });
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // GIAI ĐOẠN 4: Sound effects
  void _playSound(String soundName) {
    try {
      _audioPlayer.play(AssetSource('sounds/tieng_ting.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Helper: Format tiền tệ
  String _formatMoney(double amount) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return format.format(amount);
  }

  // Mở Calendar để chọn ngày
  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  // Lưu giao dịch (Confirm & finish)
  void _saveTransaction() async {
    if (categoryAmounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn danh mục và nhập tiền!')),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    _playSound('success');

    // Save all categories at once
    try {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      
      for (var categoryId in categoryAmounts.keys) {
        final catData = categoryAmounts[categoryId]!;
        final amount = catData['amount'] as double;
        final categoryName = catData['categoryName'] as String?;
        
        await transactionProvider.addTransaction(
          categoryName ?? 'Chi tiêu',
          amount,
          selectedDate,
          // store category as its display name to match AddTransactionScreen
          categoryName ?? 'Chi tiêu',
          true,
        );
      }
    } catch (e) {
      print('Error saving transactions: $e');
    }

    // Thông báo thành công
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Đã xác nhận tất cả giao dịch!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Quay lại màn hình cũ sau 1 giây
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context, {
            'amount': currentAmount,
            'categoryCount': categoryAmounts.length,
            'date': selectedDate,
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Vùng Trung Tâm - THE INTERACTION ZONE
          _buildWalletZone(),
          SizedBox(height: 12),
          // Hiển thị danh sách danh mục đã thêm
          if (categoryAmounts.isNotEmpty)
            _buildCategoryBreakdown(),
          SizedBox(height: 8),
          // Vùng Bên Dưới - THE SUPPLY DRAWER
          Expanded(
            child: _buildSupplyDrawer(),
          ),
        ],
      ),
    );
  }

  // GIAI ĐOẠN 1: Header Zone
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.primary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saveTransaction,
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text('Xong', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                    label: Text('Hủy', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          if (currentCategoryName != null && currentCategoryName!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Danh mục hiện tại: $currentCategoryName',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // GIAI ĐOẠN 1 & 2: Wallet DragTarget
  Widget _buildWalletZone() {
    return Center(
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
            final data = details.data;
            if (data['type'] == 'money') {
            final amt = (data['amount'] as num).toDouble();
            final img = data['image'] as String?;
            if (img != null) droppedMoneyImages.add(img);
            _onMoneyAccepted(amt);
            } else if (data['type'] == 'category') {
              _onCategoryAccepted(data['id'], data['name'], data['color']);
            }
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ví / Hóa đơn (prettier styling + animated scale)
              AnimatedScale(
                scale: _walletScale,
                duration: Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 250),
                  width: 140,
                  height: 180,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (currentCategoryColor ?? AppColors.primary).withOpacity(1.0),
                        (currentCategoryColor ?? AppColors.primary).withOpacity(0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.32),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: (currentCategoryColor ?? AppColors.primary).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 1.5),
                        ),
                        child: Icon(
                          Icons.wallet_giftcard,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tổng',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: _openNumPad,
                        child: Text(
                          _formatMoney(currentAmount),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (currentCategoryName != null && currentCategoryName!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentCategoryName!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Decorative dropped money images scattered around the wallet
              // show up to 6 last images
              ..._buildDecorativeMoneyWidgets(),

              // Nút Undo (góc trên bên trái)
              Positioned(
                top: 16,
                left: 16,
                child: GestureDetector(
                  onTap: _undo,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.undo,
                      color: currentCategoryColor ?? AppColors.primary,
                    ),
                  ),
                ),
              ),

              // Nút Reset (góc trên bên phải)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _reset,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Build transaction list display
  Widget _buildCategoryBreakdown() {
    final totalAmount = categoryAmounts.values.fold<double>(
      0,
      (sum, cat) => sum + (cat['amount'] as double),
    );
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chi tiêu theo danh mục (${categoryAmounts.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatMoney(totalAmount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          categoryAmounts.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Chưa có chi tiêu nào. Hãy chọn danh mục và thêm tiền.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryAmounts.length,
                    separatorBuilder: (_, __) => SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final categoryId = categoryAmounts.keys.toList()[index];
                      final catData = categoryAmounts[categoryId]!;
                      final amount = catData['amount'] as double;
                      final categoryName = catData['categoryName'] as String?;
                      final color = catData['color'] as Color?;
                      
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (color ?? AppColors.primary).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (color ?? AppColors.primary).withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatMoneyShort(amount),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color ?? AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              categoryName ?? 'Chi tiêu',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // Format money short version
  String formatMoneyShort(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // GIAI ĐOẠN 1: Supply Drawer
  Widget _buildSupplyDrawer() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.all(16),
      child: ListView(
        children: [
          // Hàng 1: Tiền
          Text(
            'Tờ tiền',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: moneyDenominations
                  .map((money) => _buildDraggableMoneyCard(money))
                  .toList(),
            ),
          ),
          
          // Show +/- counter if money is selected
          if (selectedMoneyId != null)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: _buildMoneyCounter(),
            ),
          
          SizedBox(height: 32),

          // Hàng 2: Danh mục
          Text(
            'Danh mục',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '(Chọn danh mục rồi thêm tiền. Có thể chọn nhiều danh mục khác nhau)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 12),
          Builder(builder: (context) {
            final catProvider = Provider.of<CategoryProvider>(context);
            final providerCats = catProvider.getCategories(isExpense: true);
            
            // Fall back to hardcoded _Categories if provider is empty
            final List<Map<String, dynamic>> categoriesToShow = providerCats.isEmpty
                ? _Categories
                : providerCats.map((c) => <String, dynamic>{
                      'name': c.name,
                      'id': c.name,
                      'color': AppColors.primary,
                      'icon': Icons.category,
                    }).toList();

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categoriesToShow.map((catData) {
                return _buildDraggableCategoryCard(catData);
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // Build +/- counter for selected money denomination
  Widget _buildMoneyCounter() {
    final selectedMoney = moneyDenominations.firstWhere(
      (m) => m['image'] == selectedMoneyId,
      orElse: () => {},
    );
    
    if (selectedMoney.isEmpty) return SizedBox.shrink();
    
    final value = (selectedMoney['value'] as num).toDouble();
    final label = selectedMoney['label'] as String;
    final totalForMoney = value * selectedMoneyCount;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Thêm $label (${_formatMoney(value)})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Minus button
              GestureDetector(
                onTap: selectedMoneyCount > 0
                    ? () {
                        setState(() {
                          selectedMoneyCount--;
                        });
                      }
                    : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selectedMoneyCount > 0
                        ? Colors.red.shade500
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              // Counter display
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$selectedMoneyCount',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'tờ',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              
              // Plus button
              GestureDetector(
                onTap: () {
                  if (currentCategory == null || currentCategory!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Vui lòng chọn danh mục trước')),);
                    return;
                  }
                  setState(() {
                    selectedMoneyCount++;
                    // Automatically add to wallet (will attribute to selected category)
                    _onMoneyAccepted(value);
                    droppedMoneyImages.add(selectedMoney['image'] as String);
                  });
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Tổng: ${_formatMoney(totalForMoney)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // GIAI ĐOẠN 2: Draggable Money Card
  Widget _buildDraggableMoneyCard(Map<String, dynamic> money) {
    final moneyValue = (money['value'] as num).toDouble();
    final isSelected = selectedMoneyId == money['image'];
    // Use a handle for dragging to avoid interfering with horizontal scroll
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  if (selectedMoneyId == money['image']) {
                    selectedMoneyId = null;
                    selectedMoneyCount = 0;
                  } else {
                    selectedMoneyId = money['image'];
                    selectedMoneyCount = 0;
                  }
                });
              },
              child: Container(
                width: 60,
                height: 80,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: Colors.yellow.shade600, width: 3) : null,
                  boxShadow: [
                    BoxShadow(
                      color: isSelected ? Colors.yellow.withOpacity(0.4) : Colors.black12,
                      blurRadius: isSelected ? 8 : 4,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    money['image'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Drag handle removed: money is now non-draggable and draggable handle replaced by static icon
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                ),
                child: Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),

        // Show counter if selected
        if (isSelected && selectedMoneyCount > 0)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$selectedMoneyCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Build small positioned widgets scattered around the wallet
  List<Widget> _buildDecorativeMoneyWidgets() {
    final widgets = <Widget>[];
    final totalImages = droppedMoneyImages.length;

    // 4 positions: top-left, top-right, bottom-left, bottom-right
    // then wrap around
    final basePositions = [
      Alignment(-0.85, -0.75),  // top-left
      Alignment(0.85, -0.75),   // top-right
      Alignment(-0.85, 0.85),   // bottom-left
      Alignment(0.85, 0.85),    // bottom-right
    ];

    for (int i = 0; i < totalImages; i++) {
      final img = droppedMoneyImages[i];
      // Distribute images around corners
      final posIndex = i % 4;
      var alignment = basePositions[posIndex];
      
      // Add slight offset for multiple images in same corner
      final offset = (i ~/ 4);
      if (offset > 0) {
        final dx = alignment.x > 0 ? 0.15 : -0.15;
        final dy = alignment.y > 0 ? 0.12 : -0.12;
        alignment = Alignment(
          (alignment.x + dx * offset * 0.3).clamp(-1.0, 1.0),
          (alignment.y + dy * offset * 0.3).clamp(-1.0, 1.0),
        );
      }

      widgets.add(
        Align(
          alignment: alignment,
          child: Container(
            width: 52,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(2, 2),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(img, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // GIAI ĐOẠN 2: Draggable Category Card
  Widget _buildDraggableCategoryCard(Map<String, dynamic> category) {
    final categoryId = category['id'] ?? 'unknown';
    final categoryName = category['name'] ?? 'Danh mục';
    final colorData = (category['color'] as Color?) ?? AppColors.primary;
    final iconData = category['icon'] as IconData?;
    final isSelected = currentCategory == categoryId;

    return Draggable<Map<String, dynamic>>(
      data: {
        'type': 'category',
        'id': categoryId.toString(),
        'name': categoryName.toString(),
        'color': colorData,
      },
      feedback: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorData,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(iconData, color: Colors.white, size: 14),
              ),
            Text(
              categoryName.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorData,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(iconData, color: Colors.white, size: 14),
              ),
            Text(
              categoryName.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
