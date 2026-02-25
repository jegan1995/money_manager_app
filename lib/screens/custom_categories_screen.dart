import 'package:flutter/material.dart';
import '../models/custom_category_model.dart';
import '../services/custom_category_service.dart';

class CustomCategoriesScreen extends StatefulWidget {
  const CustomCategoriesScreen({super.key});

  @override
  State<CustomCategoriesScreen> createState() => _CustomCategoriesScreenState();
}

class _CustomCategoriesScreenState extends State<CustomCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _svc = CustomCategoryService();
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Categories'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.remove_circle_outline), text: 'Expense'),
            Tab(icon: Icon(Icons.add_circle_outline),    text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildList('expense', isDark),
          _buildList('income', isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(
          context,
          type: _tab.index == 0 ? 'expense' : 'income',
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
      ),
    );
  }

  Widget _buildList(String type, bool isDark) {
    return StreamBuilder<List<CustomCategory>>(
      stream: _svc.getCategories(type: type),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cats = snap.data ?? [];

        if (cats.isEmpty) {
          return _emptyState(type);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: cats.length,
          itemBuilder: (ctx, i) => _catCard(cats[i], isDark),
        );
      },
    );
  }

  Widget _emptyState(String type) {
    final isExpense = type == 'expense';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isExpense ? '🏷️' : '💰',
                style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No custom ${isExpense ? 'expense' : 'income'} categories yet',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create categories that match your lifestyle.\ne.g. Petrol, Dabba, Online Classes',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openSheet(context, type: type),
              icon: const Icon(Icons.add),
              label: const Text('Create First Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catCard(CustomCategory cat, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: cat.color.withOpacity(0.4), width: 1.5),
              ),
              child: Center(
                child: Text(cat.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(cat.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: cat.subcategories.isEmpty
                ? Text('No subcategories',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400]))
                : Text(
                    cat.subcategories.take(3).join(', ') +
                        (cat.subcategories.length > 3 ? '...' : ''),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cat.type,
                    style: TextStyle(
                        fontSize: 10,
                        color: cat.color,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.grey[500], size: 18),
                  onPressed: () => _openSheet(context, cat: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: () => _confirmDelete(cat),
                ),
              ],
            ),
          ),
          // Subcategory chips
          if (cat.subcategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: cat.subcategories
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: cat.color.withOpacity(0.2)),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 11, color: cat.color)),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context,
      {CustomCategory? cat, String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        svc: _svc,
        cat: cat,
        initialType: cat?.type ?? type ?? 'expense',
      ),
    );
  }

  Future<void> _confirmDelete(CustomCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${cat.name}"?'),
        content: const Text(
            'Existing transactions with this category won\'t be affected, but it won\'t appear in new transactions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && cat.id != null) {
      await _svc.deleteCategory(cat.id!);
    }
  }
}

// ── Add / Edit Sheet ─────────────────────────────────────────────────────────
class _CategorySheet extends StatefulWidget {
  final CustomCategoryService svc;
  final CustomCategory? cat;
  final String initialType;

  const _CategorySheet({
    required this.svc,
    this.cat,
    required this.initialType,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _subCtrl   = TextEditingController();

  late String _type;
  String _selectedEmoji  = '📦';
  Color  _selectedColor  = const Color(0xFF6A1B9A);
  List<String> _subcategories = [];
  bool _saving = false;

  bool get _isEdit => widget.cat != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_isEdit) {
      _nameCtrl.text    = widget.cat!.name;
      _selectedEmoji    = widget.cat!.emoji;
      _selectedColor    = widget.cat!.color;
      _subcategories    = List.from(widget.cat!.subcategories);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  void _addSubcategory() {
    final sub = _subCtrl.text.trim();
    if (sub.isEmpty) return;
    if (_subcategories.contains(sub)) {
      _snack('Already added');
      return;
    }
    setState(() => _subcategories.add(sub));
    _subCtrl.clear();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();

    // Check duplicate name
    final exists = await widget.svc.nameExists(
      name, _type,
      excludeId: widget.cat?.id,
    );
    if (exists) {
      _snack('A category named "$name" already exists');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final cat = CustomCategory(
        id:             widget.cat?.id,
        userId:         '',  // service injects real uid
        name:           name,
        type:           _type,
        emoji:          _selectedEmoji,
        colorValue:     _selectedColor.value,
        subcategories:  _subcategories,
        createdAt:      _isEdit ? widget.cat!.createdAt : now,
      );

      if (_isEdit) {
        await widget.svc.updateCategory(cat);
      } else {
        await widget.svc.addCategory(cat);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Text(_isEdit ? 'Edit Category' : 'New Category',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Type toggle (only when creating)
              if (!_isEdit) ...[
                Row(
                  children: [
                    Expanded(child: _typeBtn('expense', '📉 Expense', Colors.red)),
                    const SizedBox(width: 10),
                    Expanded(child: _typeBtn('income', '📈 Income', Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Preview + Name row
              Row(
                children: [
                  // Emoji preview
                  GestureDetector(
                    onTap: _pickEmoji,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _selectedColor.withOpacity(0.5),
                            width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_selectedEmoji,
                              style: const TextStyle(fontSize: 22)),
                          Text('tap',
                              style: TextStyle(
                                  fontSize: 8, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Category Name *',
                        hintText: 'e.g. Petrol, Dabba, SIP',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name required'
                          : v.trim().length < 2
                              ? 'Too short'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Color picker
              Text('Color',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCategoryColors.map((c) {
                  final sel = c.value == _selectedColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: sel ? 34 : 28,
                      height: sel ? 34 : 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: sel
                            ? [BoxShadow(
                                color: c.withOpacity(0.5),
                                blurRadius: 6)]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Subcategories
              Text('Subcategories (optional)',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Office, Home',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onFieldSubmitted: (_) => _addSubcategory(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addSubcategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_subcategories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _subcategories
                      .map((s) => Chip(
                            label: Text(s,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                _selectedColor.withOpacity(0.1),
                            side: BorderSide(
                                color: _selectedColor.withOpacity(0.3)),
                            deleteIcon: Icon(Icons.close,
                                size: 14, color: _selectedColor),
                            onDeleted: () => setState(
                                () => _subcategories.remove(s)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEdit
                              ? 'Update Category'
                              : 'Create Category',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String type, String label, Color color) {
    final sel = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : color)),
        ),
      ),
    );
  }

  void _pickEmoji() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick Emoji',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryEmojis.map((e) {
                final sel = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedEmoji = e);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sel
                          ? _selectedColor.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: sel
                          ? Border.all(color: _selectedColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(e,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}