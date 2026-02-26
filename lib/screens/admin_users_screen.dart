import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _admin = AdminService();
  String _filter = 'all'; // all, active, suspended
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // ── Search bar ────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF1A237E),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // ── Filter chips ───────────────────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF1A2035) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _filterChip('All',       'all',       isDark),
            const SizedBox(width: 8),
            _filterChip('Active',    'active',    isDark),
            const SizedBox(width: 8),
            _filterChip('Suspended', 'suspended', isDark),
            const SizedBox(width: 8),
            _filterChip('Limited',   'limited',   isDark),
          ]),
        ),

        // ── User list ──────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _admin.getAllUsers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var users = snap.data ?? [];

              // Apply filter
              if (_filter != 'all') {
                if (_filter == 'limited') {
                  users = users.where((u) => u.access == 'limited').toList();
                } else {
                  users = users.where((u) => u.status == _filter).toList();
                }
              }

              // Apply search
              if (_search.isNotEmpty) {
                users = users.where((u) =>
                    u.name.toLowerCase().contains(_search) ||
                    u.email.toLowerCase().contains(_search)).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No users found',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) =>
                    _userCard(users[i], isDark),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A237E)
              : isDark
                  ? const Color(0xFF1E2530)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1A237E)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  selected ? Colors.white : Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _userCard(AppUser user, bool isDark) {
    final isAdmin = user.uid == kAdminUID;
    final statusColor = user.status == 'active'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);
    final accessColor = _accessColor(user.access);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => AdminUserDetailScreen(user: user))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 6)
          ],
          border: isAdmin
              ? Border.all(
                  color: const Color(0xFF1A237E).withOpacity(0.4),
                  width: 1.5)
              : null,
        ),
        child: Column(children: [
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: isAdmin
                  ? const Color(0xFF1A237E).withOpacity(0.15)
                  : const Color(0xFF1565C0).withOpacity(0.1),
              child: isAdmin
                  ? const Icon(Icons.shield,
                      color: Color(0xFF1A237E), size: 22)
                  : Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
            ),
            const SizedBox(width: 14),
            // Name + email
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  if (isAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ADMIN',
                          style: TextStyle(
                              color: Color(0xFF1A237E),
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(user.email,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (user.lastActive != null)
                  Text(
                    'Last active: ${DateFormat('dd MMM, hh:mm a').format(user.lastActive!)}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[400]),
                  ),
              ],
            )),
            // Status badges
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              _badge(user.status.toUpperCase(), statusColor),
              const SizedBox(height: 4),
              _badge(_accessLabel(user.access), accessColor),
            ]),
          ]),

          if (!isAdmin) ...[
            const SizedBox(height: 12),
            // Quick action buttons
            Row(children: [
              Expanded(
                child: _quickBtn(
                  label: user.status == 'active' ? 'Suspend' : 'Activate',
                  color: user.status == 'active'
                      ? Colors.red
                      : Colors.green,
                  icon: user.status == 'active'
                      ? Icons.block
                      : Icons.check_circle,
                  onTap: () => _toggleStatus(user),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickBtn(
                  label: 'Set Access',
                  color: const Color(0xFF1565C0),
                  icon: Icons.tune,
                  onTap: () => _showAccessDialog(user),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickBtn(
                  label: 'Details',
                  color: const Color(0xFF7B1FA2),
                  icon: Icons.manage_accounts,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AdminUserDetailScreen(user: user))),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );

  Widget _quickBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Future<void> _toggleStatus(AppUser user) async {
    final newStatus =
        user.status == 'active' ? 'suspended' : 'active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newStatus == 'suspended'
            ? 'Suspend User?'
            : 'Activate User?'),
        content: Text(newStatus == 'suspended'
            ? '${user.name} will not be able to use the app.'
            : '${user.name} will regain full access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'suspended'
                    ? Colors.red
                    : Colors.green),
            child: Text(newStatus == 'suspended'
                ? 'Suspend'
                : 'Activate',
                style:
                    const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _admin.updateUserStatus(user.uid, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.name} is now $newStatus'),
          backgroundColor: newStatus == 'active'
              ? Colors.green
              : Colors.red,
        ));
      }
    }
  }

  Future<void> _showAccessDialog(AppUser user) async {
    String selected = user.access;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Set Access for ${user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _accessOption('Full Access', 'full',
                  Icons.lock_open, Colors.green, selected,
                  (v) => setS(() => selected = v)),
              _accessOption('Limited Access', 'limited',
                  Icons.lock, Colors.orange, selected,
                  (v) => setS(() => selected = v)),
              _accessOption('Read Only', 'readonly',
                  Icons.visibility, Colors.blue, selected,
                  (v) => setS(() => selected = v)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _admin.updateUserAccess(user.uid, selected);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Access updated to ${_accessLabel(selected)}'),
                    backgroundColor: Colors.green,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E)),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accessOption(String label, String value,
      IconData icon, Color color, String selected,
      Function(String) onSelect) =>
      RadioListTile<String>(
        value:    value,
        groupValue: selected,
        onChanged: (v) => onSelect(v!),
        activeColor: color,
        title: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ]),
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
      default:         return 'Full';
    }
  }
}