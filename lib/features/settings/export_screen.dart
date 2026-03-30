import 'dart:typed_data';
import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatting.dart';
import '../transactions/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _transactionType = 'both';
  String _detailType = 'summary';
  String _exportFormat = 'pdf';
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    // Default to current month range
    _setThisMonthRange();
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final initial = _fromDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _fromController.text = Formatting.formatDate(picked);
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initial = _toDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _toController.text = Formatting.formatDate(picked);
      });
    }
  }

  Future<List<TransactionModel>> _filteredTransactions() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final list = provider.transactions;
    return list.where((t) {
      if (_fromDate != null && t.date.isBefore(_fromDate!)) {
        return false;
      }
      if (_toDate != null &&
          t.date.isAfter(
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59),
          )) {
        return false;
      }
      if (_transactionType == 'expense' && !t.isExpense) {
        return false;
      }
      if (_transactionType == 'income' && t.isExpense) {
        return false;
      }
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(t.category)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<Uint8List> _generatePdfBytes(List<TransactionModel> txs) async {
    // Load a TTF font from assets and embed it into the PDF so Vietnamese
    // characters render correctly. Place the font file at
    // `assets/fonts/NotoSans-Regular.ttf` (or another TTF supporting Vietnamese)
    // and add it under `flutter.assets` in pubspec.yaml.
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) {
          final rows = txs
              .map(
                (t) => [
                  Formatting.formatDate(t.date),
                  t.title,
                  t.category,
                  (t.isExpense ? '-' : '+') + Formatting.formatCurrency(t.amount),
                ],
              )
              .toList();

          final headerStyle = pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold);
          final normalStyle = pw.TextStyle(font: ttf, fontSize: 11);
          final tableHeaderStyle = pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold);
          final tableCellStyle = pw.TextStyle(font: ttf, fontSize: 10);

          return [
            pw.Header(level: 0, child: pw.Text('Báo cáo giao dịch', style: headerStyle)),
            pw.Paragraph(
              text:
                  'Loại: ${_transactionType == 'both' ? 'Cả hai' : (_transactionType == 'expense' ? 'Chi tiêu' : 'Thu nhập')}. Định dạng: ${_exportFormat.toUpperCase()}',
              style: normalStyle,
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Ngày', 'Tiêu đề', 'Danh mục', 'Số tiền'],
              data: rows,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: tableHeaderStyle,
              cellStyle: tableCellStyle,
            ),
            pw.Divider(),
            pw.Paragraph(
              text:
                  'Tổng: ${Formatting.formatCurrency(txs.fold<double>(0, (p, e) => p + (e.isExpense ? -e.amount : e.amount)))}',
              style: normalStyle,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<void> _savePdfFile(List<TransactionModel> txs) async {
    try {
      final bytes = await _generatePdfBytes(txs);
      // Lưu vào app's Documents directory (không cần quyền phức tạp)
      final dir = await getApplicationDocumentsDirectory();
      
      final fileName = 'transactions_${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}_${DateTime.now().minute.toString().padLeft(2, '0')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu PDF: ${file.path}')),
      );
      
      // Mở file bằng share dialog
      await Share.shareXFiles([XFile(file.path)], text: 'Báo cáo giao dịch');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu PDF: $e')),
      );
    }
  }

  Future<void> _showPdfPreview(List<TransactionModel> txs) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Xem trước'),
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  _savePdfFile(txs);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: PdfPreview(build: (format) => _generatePdfBytes(txs)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _setRange(DateTime from, DateTime to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
      _fromController.text = Formatting.formatDate(from);
      _toController.text = Formatting.formatDate(to);
    });
  }

  void _setThisMonthRange() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    _setRange(from, to);
  }

  void _setLastMonthRange() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final from = DateTime(lastMonth.year, lastMonth.month, 1);
    final to = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    _setRange(from, to);
  }

  void _setLast3MonthsRange() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 2, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    _setRange(from, to);
  }

  void _onExport() async {
    final txs = await _filteredTransactions();
    if (!mounted) return;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có giao dịch để xuất')),
      );
      return;
    }

    if (_exportFormat == 'pdf') {
      await _showPdfPreview(txs);
      if (!mounted) return;
    } else {
      await _showExcelPreview(txs);
      if (!mounted) return;
    }
  }

  Future<void> _showExcelPreview(List<TransactionModel> txs) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Xem trước Excel'),
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  _exportExcel(txs);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildExcelPreviewTable(txs),
          ),
        ),
      ),
    );
  }

  Widget _buildExcelPreviewTable(List<TransactionModel> txs) {
    final headers = ['Ngày', 'Tiêu đề', 'Danh mục', 'Số tiền'];
    final total = txs.fold<double>(0, (p, e) => p + (e.isExpense ? -e.amount : e.amount));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Báo cáo giao dịch',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
            rows: txs.map((t) => DataRow(cells: [
              DataCell(Text(Formatting.formatDate(t.date))),
              DataCell(Text(t.title)),
              DataCell(Text(t.category)),
              DataCell(Text(
                (t.isExpense ? '-' : '+') + Formatting.formatCurrency(t.amount),
                style: TextStyle(color: t.isExpense ? Colors.red : Colors.green),
              )),
            ])).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                Formatting.formatCurrency(total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: total >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportExcel(List<TransactionModel> txs) async {
    try {
      // Create workbook and sheet
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      int rowIndex = 0;
      final headers = ['Ngày', 'Tiêu đề', 'Danh mục', 'Số tiền'];
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          headers[c],
        );
      }
      rowIndex++;

      for (final t in txs) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          Formatting.formatDate(t.date),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          t.title,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          t.category,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          (t.isExpense ? '-' : '') + Formatting.formatCurrency(t.amount),
        );
        rowIndex++;
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Không tạo được file Excel');

      // Lưu vào app's Documents directory (không cần quyền phức tạp)
      final dir = await getApplicationDocumentsDirectory();
      
      final fileName = 'transactions_${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}_${DateTime.now().hour.toString().padLeft(2, '0')}_${DateTime.now().minute.toString().padLeft(2, '0')}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu Excel: ${file.path}')),
      );

      // Mở file bằng share dialog
      await Share.shareXFiles([XFile(file.path)], text: 'Báo cáo giao dịch');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xuất Excel: $e')));
    }
  }

  Widget _buildRadioCard({
    required String value,
    required Widget child,
    required String groupValue,
    required void Function(String?) onChanged,
  }) {
    final checked = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: checked
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildDetailOption(String value, String title, String subtitle) {
    final checked = value == _detailType;
    return ListTile(
      onTap: () => setState(() => _detailType = value),
      leading: Icon(
        checked ? Icons.radio_button_checked : Icons.radio_button_off,
        color: checked ? AppColors.primary : Colors.grey,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Xuất Khoản Chi & Thu'),
        leading: BackButton(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _onExport,
            child: Text(
              'Xem trước',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Loại giao dịch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioCard(
                      value: 'both',
                      groupValue: _transactionType,
                      onChanged: (v) => setState(() {
                        final newV = v ?? 'both';
                        if (newV != _transactionType) {
                          _selectedCategories.clear();
                        }
                        _transactionType = newV;
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.swap_vert,
                            color: Colors.blue,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Cả hai',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRadioCard(
                      value: 'expense',
                      groupValue: _transactionType,
                      onChanged: (v) => setState(() {
                        final newV = v ?? 'expense';
                        if (newV != _transactionType) {
                          _selectedCategories.clear();
                        }
                        _transactionType = newV;
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            color: Colors.red,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Chi tiêu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRadioCard(
                      value: 'income',
                      groupValue: _transactionType,
                      onChanged: (v) => setState(() {
                        final newV = v ?? 'income';
                        if (newV != _transactionType) {
                          _selectedCategories.clear();
                        }
                        _transactionType = newV;
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Thu nhập',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Text(
                'Chi tiết báo cáo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  _buildDetailOption(
                    'summary',
                    'Tổng hợp',
                    'Danh sách đầy đủ theo thời gian',
                  ),
                  _buildDetailOption(
                    'by_category',
                    'Theo danh mục',
                    'Phân nhóm theo Ăn uống, Đi lại...',
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Text(
                'Khoảng thời gian',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Từ ngày',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _fromController,
                          readOnly: true,
                          onTap: _pickFromDate,
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _pickFromDate,
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đến ngày',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _toController,
                          readOnly: true,
                          onTap: _pickToDate,
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _pickToDate,
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_detailType == 'by_category') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final provider = Provider.of<TransactionProvider>(
                      context,
                      listen: false,
                    );
                    final bool? isExpenseFilter = _transactionType == 'both'
                        ? null
                        : (_transactionType == 'expense');
                    // Default categories
                    const defaultExpense = [
                      'Ăn uống',
                      'Di chuyển',
                      'Mua sắm',
                      'Giải trí',
                      'Hóa đơn',
                    ];
                    const defaultIncome = [
                      'Lương',
                      'Thưởng',
                      'Bán đồ',
                      'Tiền lãi',
                    ];

                    final providerCats = provider.getCategories(
                      isExpense: isExpenseFilter,
                    );

                    final combinedSet = <String>{};
                    if (isExpenseFilter == null) {
                      combinedSet.addAll(defaultExpense);
                      combinedSet.addAll(defaultIncome);
                    } else if (isExpenseFilter) {
                      combinedSet.addAll(defaultExpense);
                    } else {
                      combinedSet.addAll(defaultIncome);
                    }
                    combinedSet.addAll(providerCats);

                    final categories = combinedSet.toList()
                      ..sort((a, b) => a.compareTo(b));

                    final selected = Set<String>.from(_selectedCategories);

                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (c) {
                        return StatefulBuilder(
                          builder: (context, setStateSheet) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Chọn danh mục',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: categories.map((cat) {
                                      final sel = selected.contains(cat);
                                      return ChoiceChip(
                                        label: Text(cat),
                                        selected: sel,
                                        onSelected: (v) => setStateSheet(
                                          () => v
                                              ? selected.add(cat)
                                              : selected.remove(cat),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Huỷ'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedCategories.clear();
                                            _selectedCategories.addAll(
                                              selected,
                                            );
                                          });
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Áp dụng'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Text('Chọn danh mục'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _selectedCategories
                      .map((c) => Chip(label: Text(c)))
                      .toList(),
                ),
              ],

              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _setThisMonthRange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Tháng này'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _setLastMonthRange,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Tháng trước'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _setLast3MonthsRange,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('3 tháng qua'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Định dạng xuất',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioCard(
                      value: 'pdf',
                      groupValue: _exportFormat,
                      onChanged: (v) =>
                          setState(() => _exportFormat = v ?? 'pdf'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PDF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tối ưu in ấn',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRadioCard(
                      value: 'excel',
                      groupValue: _exportFormat,
                      onChanged: (v) =>
                          setState(() => _exportFormat = v ?? 'excel'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.table_chart,
                            color: Colors.green,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Excel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Dữ liệu thô',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: ElevatedButton.icon(
            onPressed: _onExport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            icon: const FaIcon(FontAwesomeIcons.shareFromSquare),
            label: const Text(
              'Xuất báo cáo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
