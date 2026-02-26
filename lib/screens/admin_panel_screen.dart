import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import 'admin_users_screen.dart';
import 'admin_broadcast_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _admin = AdminService();
  AppStats? _stats;
  bool _loading = true;
  List<AppUser> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _ensureAdmin();
    _load();
  }

  Future<void> _ensureAdmin() async {
    await _admin.ensureAdminRecord();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _admin.getAppStats();
      final users = await _admin.getAllUsers().first;
      setState(() {
        _stats       = stats;
        _recentUsers = users.take(5).toList();
        _loading     = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Master Control Panel'),
        ]),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [

                  // ── Admin Badge ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF283593)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF1A237E).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Super Admin',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('Full control over the app',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.shade300, width: 1),
                        ),
                        child: const Text('ACTIVE',
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ── App Stats ───────────────────────────────────────────
                  _sectionLabel('App Statistics'),
                  const SizedBox(height: 8),
                  if (_stats != null) ...[
                    Row(children: [
                      _statCard('Total Users',
                          '${_stats!.totalUsers}',
                          Icons.people,
                          const Color(0xFF1565C0), isDark),
                      const SizedBox(width: 10),
                      _statCard('Active Today',
                          '${_stats!.activeToday}',
                          Icons.bolt,
                          const Color(0xFF2E7D32), isDark),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _statCard('Transactions',
                          '${_stats!.totalTransactions}',
                          Icons.receipt_long,
                          const Color(0xFF7B1FA2), isDark),
                      const SizedBox(width: 10),
                      _statCard('Total Volume',
                          _fmtShort(_stats!.totalVolume),
                          Icons.currency_rupee,
                          const Color(0xFFE65100), isDark),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // ── Quick Actions ───────────────────────────────────────
                  _sectionLabel('Quick Actions'),
                  const SizedBox(height: 8),
                  _card(isDark, children: [
                    _action(context,
                      icon: Icons.people_alt,
                      title: 'Manage Users',
                      subtitle: 'View, enable/disable, set access levels',
                      color: const Color(0xFF1565C0),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AdminUsersScreen())),
                    ),
                    _divider(),
                    _action(context,
                      icon: Icons.campaign,
                      title: 'Broadcast Message',
                      subtitle: 'Send notification to all users',
                      color: const Color(0xFF7B1FA2),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AdminBroadcastScreen())),
                    ),
                    _divider(),
                    _action(context,
                      icon: Icons.bar_chart,
                      title: 'Refresh Statistics',
                      subtitle: 'Reload app-wide stats',
                      color: const Color(0xFF2E7D32),
                      onTap: _load,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Recent Users ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Recent Users'),
                      TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const AdminUsersScreen())),
                        child: const Text('See all',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1565C0))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _card(isDark,
                      children: _recentUsers.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                    child: Text('No users yet',
                                        style: TextStyle(
                                            color: Colors.grey))),
                              )
                            ]
                          : _recentUsers
                              .map((u) => Column(children: [
                                    _userRow(u, isDark),
                                    if (u != _recentUsers.last) _divider(),
                                  ]))
                              .toList()),

                  const SizedBox(height: 20),

                  // ── Access Level Guide ──────────────────────────────────
                  _sectionLabel('Access Level Guide'),
                  const SizedBox(height: 8),
                  _card(isDark, children: [
                    _accessGuide('Full Access', 'All features enabled',
                        Icons.lock_open, Colors.green, isDark),
                    _divider(),
                    _accessGuide('Limited Access',
                        'View & add only — no export/import/PDF',
                        Icons.lock, Colors.orange, isDark),
                    _divider(),
                    _accessGuide('Read Only',
                        'View transactions only — cannot add/edit/delete',
                        Icons.visibility, Colors.blue, isDark),
                    _divider(),
                    _accessGuide('Suspended',
                        'Account disabled — cannot login to app',
                        Icons.block, Colors.red, isDark),
                  ]),

                ],
              ),
            ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.1),
        ),
      );

  Widget _statCard(String label, String value,
      IconData icon, Color color, bool isDark) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 6)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      );

  Widget _card(bool isDark, {required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() =>
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1));

  Widget _action(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            )),
            Icon(Icons.chevron_right, color: Colors.grey[300], size: 18),
          ]),
        ),
      );

  Widget _userRow(AppUser user, bool isDark) {
    final statusColor = user.status == 'active'
        ? Colors.green
        : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(user.email,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(user.status.toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(_accessLabel(user.access),
              style: TextStyle(fontSize: 9, color: Colors.grey[400])),
        ]),
      ]),
    );
  }

  Widget _accessGuide(String title, String desc,
      IconData icon, Color color, bool isDark) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13, color: color)),
              Text(desc,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          )),
        ]),
      );

  String _accessLabel(String a) {
    switch (a) {
      case 'limited':  return 'Limited';
      case 'readonly': return 'Read Only';
      default:         return 'Full Access';
    }
  }

  String _fmtShort(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }
}