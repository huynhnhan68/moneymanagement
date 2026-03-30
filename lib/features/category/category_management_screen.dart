import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import 'category_provider.dart';
import '../../data/models/category_model.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _nameCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Tên')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          ElevatedButton(onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            await Provider.of<CategoryProvider>(context, listen: false).addCategory(name: name);
            Navigator.of(ctx).pop();
          }, child: const Text('Thêm'))
        ],
      ),
    );
  }

  void _showEditDialog(CategoryModel cat) {
    _nameCtrl.text = cat.name;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Tên')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          ElevatedButton(onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final updated = CategoryModel(id: cat.id, name: name);
            await Provider.of<CategoryProvider>(context, listen: false).updateCategory(updated);
            Navigator.of(ctx).pop();
          }, child: const Text('Lưu'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CategoryProvider>(context);
    final cats = provider.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý danh mục')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final c = cats[i];
          final isDefault = provider.isDefaultCategory(c.id);
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary, child: const Icon(Icons.category, color: Colors.white)),
              title: Text(c.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: isDefault ? null : () => _showEditDialog(c),
                ),
                IconButton(
                  icon: isDefault ? const Icon(Icons.lock) : const Icon(Icons.delete),
                  onPressed: isDefault
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Xác nhận'),
                              content: const Text('Bạn muốn xóa danh mục này?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
                                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await Provider.of<CategoryProvider>(context, listen: false).deleteCategory(c.id);
                          }
                        },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
