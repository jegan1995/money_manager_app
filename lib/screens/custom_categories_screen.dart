// lib/screens/custom_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // Seed categories on first open
    Future.microtask(() async {
      await _svc.seedBuiltInIfEmpty(type: 'expense');
      await _svc.seedBuiltInIfEmpty(type: 'income');
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('Manage Categories',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF667eea),
          tabs: const [Tab(text: '💸 Expense'), Tab(text: '💰 Income')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(_tabs.index == 0 ? 'expense' : 'income'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CatList(type: 'expense', svc: _svc, isDark: isDark),
          _CatList(type: 'income',  svc: _svc, isDark: isDark),
        ],
      ),
    );
  }

  void _openAddSheet(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddCatSheet(type: type, svc: _svc),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CatList extends StatelessWidget {
  final String type;
  final CustomCategoryService svc;
  final bool isDark;
  const _CatList({required this.type, required this.svc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomCategory>>(
      stream: svc.getCategories(type: type),
      builder: (_, snap) {
        if (snap.hasError) {
          final errMsg = snap.error?.toString() ?? 'Unknown error';
          final isPermission = errMsg.contains('permission') ||
              errMsg.contains('PERMISSION') ||
              errMsg.contains('Missing or insufficient');
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPermission ? Icons.lock_outline_rounded : Icons.error_outline,
                  color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  isPermission
                      ? 'Firestore Permission Denied'
                      : 'Failed to load categories',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (isPermission) ...[
                  const Text(
                    'Add this rule to Firebase Console →\nFirestore → Rules:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'match /custom_categories/{id} {\n'
                      '  allow read, write: if request.auth != null\n'
                      '    && request.auth.uid ==\n'
                      '    resource.data.userId;\n'
                      '}',
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ] else
                  Text(errMsg,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 11),
                      textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await svc.seedBuiltInIfEmpty(type: type);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ));
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)));
        }
        final cats = snap.data ?? [];
        if (cats.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📂', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 14),
            const Text('No categories yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Tap + to create a $type category',
                style: const TextStyle(color: Colors.grey)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          itemCount: cats.length,
          itemBuilder: (_, i) => _CatTile(cat: cats[i], svc: svc, isDark: isDark),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CatTile extends StatefulWidget {
  final CustomCategory cat;
  final CustomCategoryService svc;
  final bool isDark;
  const _CatTile({required this.cat, required this.svc, required this.isDark});
  @override State<_CatTile> createState() => _CatTileState();
}

class _CatTileState extends State<_CatTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cat  = widget.cat;
    final card = widget.isDark ? const Color(0xFF1E2530) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: _expanded
              ? const BorderRadius.vertical(top: Radius.circular(14))
              : BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(cat.emoji,
                    style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.name, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${cat.subcategories.length} subcategories',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              )),
              if (!cat.isBuiltIn) ...[
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 17, color: Colors.grey[400]),
                  onPressed: () => _edit(context, cat),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                  onPressed: () => _delete(context, cat),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ] else
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('built-in',
                      style: TextStyle(fontSize: 9, color: Colors.grey)),
                ),
              Icon(_expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey[400], size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: widget.isDark ? Colors.white12 : Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Subcategories', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                if (!cat.isBuiltIn)
                  GestureDetector(
                    onTap: () => _addSubSheet(context, cat),
                    child: Text('+ Add',
                        style: TextStyle(fontSize: 11, color: cat.color,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 8),
              if (cat.subcategories.isEmpty)
                Text('No subcategories yet',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]))
              else
                ...cat.subcategories.map((sub) => _SubRow(
                    sub: sub, cat: cat, svc: widget.svc, isDark: widget.isDark)),
            ]),
          ),
        ],
      ]),
    );
  }

  void _edit(BuildContext ctx, CustomCategory cat) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddCatSheet(type: cat.type, svc: widget.svc, existing: cat),
    );
  }

  Future<void> _delete(BuildContext ctx, CustomCategory cat) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
        content: Text('Delete "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.deleteCategory(cat.id!);
      HapticFeedback.mediumImpact();
    }
  }

  void _addSubSheet(BuildContext ctx, CustomCategory cat) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20,
            MediaQuery.of(bctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text('Add subcategory to ${cat.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl, autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Subcategory name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(bctx);
                final newSubs = [...cat.subcategories,
                    CustomSubcategory(name: ctrl.text.trim())];
                await widget.svc.updateCategory(
                    cat.id!, cat.copyWith(subcategories: newSubs));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cat.color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SubRow extends StatelessWidget {
  final CustomSubcategory sub;
  final CustomCategory cat;
  final CustomCategoryService svc;
  final bool isDark;
  const _SubRow({required this.sub, required this.cat, required this.svc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sub.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          if (sub.subSubs.isNotEmpty)
            Wrap(spacing: 4, runSpacing: 3, children: sub.subSubs.map((s) =>
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 10, color: cat.color)),
                )).toList()),
        ])),
        if (!cat.isBuiltIn)
          GestureDetector(
            onTap: () async {
              final newSubs = cat.subcategories.where((s) => s.name != sub.name).toList();
              await svc.updateCategory(cat.id!, cat.copyWith(subcategories: newSubs));
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.grey),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AddCatSheet extends StatefulWidget {
  final String type;
  final CustomCategoryService svc;
  final CustomCategory? existing;
  const _AddCatSheet({required this.type, required this.svc, this.existing});
  @override State<_AddCatSheet> createState() => _AddCatSheetState();
}

class _AddCatSheetState extends State<_AddCatSheet> {
  final _ctrl = TextEditingController();
  String _emoji = '📌';
  Color  _color = const Color(0xFF667eea);

  static const _emojis = ['📌','🍽️','🛍️','🚗','💡','🎬','🏥','📚','💆','✈️',
      '💼','🏢','💻','📈','🎁','💰','🏠','⚽','🎮','📱','🎵'];
  static const _colors = [
    Color(0xFF667eea), Color(0xFFfa709a), Color(0xFFf6d365),
    Color(0xFF43b89c), Color(0xFFa18cd1), Color(0xFF30cfd0),
    Color(0xFF764ba2), Color(0xFFfe6b8b), Color(0xFF0ba360),
    Color(0xFFf77062), Color(0xFF95a5a6), Color(0xFFe53935),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _ctrl.text = widget.existing!.name;
      _emoji = widget.existing!.emoji;
      _color = widget.existing!.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isEdit ? 'Edit Category' : 'New Category',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Choose Icon', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(height: 50, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _emojis.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _emoji = _emojis[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _emoji == _emojis[i]
                      ? _color.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _emoji == _emojis[i] ? _color : Colors.transparent,
                      width: 2),
                ),
                child: Center(child: Text(_emojis[i],
                    style: const TextStyle(fontSize: 22))),
              ),
            ),
          )),
          const SizedBox(height: 14),
          const Text('Choose Color', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) =>
            GestureDetector(
              onTap: () => setState(() => _color = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(
                      color: _color == c ? Colors.white : Colors.transparent,
                      width: 2),
                  boxShadow: _color == c
                      ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 6)]
                      : null,
                ),
                child: _color == c
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            )).toList()),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category Name *',
              prefixText: '$_emoji ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (_ctrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                if (isEdit) {
                  await widget.svc.updateCategory(widget.existing!.id!,
                      widget.existing!.copyWith(
                          name: _ctrl.text.trim(), emoji: _emoji, color: _color));
                } else {
                  await widget.svc.addCategory(CustomCategory(
                    userId: '', type: widget.type,
                    name: _ctrl.text.trim(), emoji: _emoji, color: _color,
                  ));
                }
                HapticFeedback.lightImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _color, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isEdit ? 'Save Changes' : 'Create Category',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      )),
    );
  }
}