import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final AppUser user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends State<AdminUserDetailScreen> {
  final _admin = AdminService();
  late Map<String, bool> _features;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _features = Map.from(widget.user.effectiveFeatures);
  }

  Future<void> _saveFeatures() async {
    setState(() => _saving = true);
    try {
      await _admin.updateUserFeatures(widget.user.uid, _features);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Feature permissions saved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isAdmin  = widget.user.uid == kAdminUID;
    final statusColor = widget.user.status == 'active'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.user.name),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (!isAdmin)
            TextButton(
              onPressed: _saving ? null : _saveFeatures,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [

          // ── Profile card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8)
              ],
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    const Color(0xFF1565C0).withOpacity(0.1),
                child: isAdmin
                    ? const Icon(Icons.shield,
                        color: Color(0xFF1A237E), size: 32)
                    : Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                            fontSize: 28),
                      ),
              ),
              const SizedBox(height: 12),
              Text(widget.user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text(widget.user.email,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[400])),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                _infoBadge(
                    widget.user.status.toUpperCase(),
                    statusColor),
                const SizedBox(width: 8),
                _infoBadge(
                    _accessLabel(widget.user.access),
                    _accessColor(widget.user.access)),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  _infoBadge('SUPER ADMIN',
                      const Color(0xFF1A237E)),
                ],
              ]),
              const SizedBox(height: 12),
              if (widget.user.createdAt != null)
                Text(
                  'Joined: ${DateFormat('dd MMM yyyy').format(widget.user.createdAt!)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400]),
                ),
              if (widget.user.lastActive != null)
                Text(
                  'Last active: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.user.lastActive!)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400]),
                ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Feature Permissions ─────────────────────────────────────
          if (!isAdmin) ...[
            _sectionLabel('Feature Permissions'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2530) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8)
                ],
              ),
              child: Column(
                children: _featureList.asMap().entries.map((e) {
                  final feat = e.value;
                  return Column(children: [
                    SwitchListTile(
                      value: _features[feat.key] ?? true,
                      onChanged: (v) =>
                          setState(() => _features[feat.key] = v),
                      activeColor: const Color(0xFF1565C0),
                      title: Row(children: [
                        Icon(feat.icon,
                            color: feat.color, size: 18),
                        const SizedBox(width: 10),
                        Text(feat.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]),
                      subtitle: Text(feat.desc,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400])),
                    ),
                    if (e.key < _featureList.length - 1)
                      Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.grey.withOpacity(0.1)),
                  ]);
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap Save in the top right to apply permission changes.',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  List<_FeatureItem> get _featureList => [
    _FeatureItem('budget',    'Budget',       Icons.pie_chart,        Colors.orange,
        'Set and track budgets'),
    _FeatureItem('reports',   'Reports',      Icons.bar_chart,        const Color(0xFF1565C0),
        'View reports and analytics'),
    _FeatureItem('goals',     'Goals',        Icons.flag,             Colors.green,
        'Set and track financial goals'),
    _FeatureItem('transfers', 'Transfers',    Icons.swap_horiz,       Colors.teal,
        'Transfer between accounts'),
    _FeatureItem('recurring', 'Recurring',    Icons.repeat,           Colors.purple,
        'Recurring transactions'),
    _FeatureItem('export',    'Export',       Icons.download,         Colors.indigo,
        'Export transaction data'),
    _FeatureItem('import',    'Import',       Icons.upload,           Colors.brown,
        'Import from Excel/CSV'),
    _FeatureItem('pdfReport', 'PDF Report',   Icons.picture_as_pdf,   Colors.red,
        'Generate monthly PDF reports'),
    _FeatureItem('emiCalc',   'EMI Calculator', Icons.calculate,      Colors.cyan,
        'Calculate loan EMIs'),
    _FeatureItem('netWorth',  'Net Worth',    Icons.account_balance,  Colors.indigo,
        'Track net worth tracker'),
    _FeatureItem('search',    'Search',       Icons.search,           Colors.blueGrey,
        'Search transactions'),
    _FeatureItem('calendar',  'Calendar',     Icons.calendar_month,   Colors.teal,
        'Calendar view'),
    _FeatureItem('categories','Categories',   Icons.category,         Colors.brown,
        'Custom categories'),
    _FeatureItem('family',    'Family Mode',  Icons.people_alt,       const Color(0xFF7B1FA2),
        'Access family group and shared finances'),
  ];

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 1.1)),
      );

  Widget _infoBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Color _accessColor(String a) {
    switch (a) {
      case 'limited':  return Colors.orange;
      case 'readonly': return Colors.blue;
      default:         return Colors.green;
    }
  }

  String _accessLabel(String a) {
    switch (a) {
      case 'limited':  return 'Limited';
      case 'readonly': return 'Read Only';
      default:         return 'Full Access';
    }
  }
}

class _FeatureItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String desc;
  const _FeatureItem(
      this.key, this.label, this.icon, this.color, this.desc);
}