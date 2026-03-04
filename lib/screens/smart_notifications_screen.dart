// lib/screens/smart_notifications_screen.dart
// Feature 20 — Smart Notification Center
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/smart_notification_service.dart';

class SmartNotificationsScreen extends StatefulWidget {
  const SmartNotificationsScreen({super.key});
  @override
  State<SmartNotificationsScreen> createState() =>
      _SmartNotificationsScreenState();
}

class _SmartNotificationsScreenState
    extends State<SmartNotificationsScreen> {
  final _svc      = SmartNotificationService();
  bool  _loading  = false;
  String _filter  = 'all'; // all | budget | goal | recurring | spending

  // ── Type config ────────────────────────────────────────────────────────────
  static const _typeConfig = {
    'budget':    {'label': 'Budget',    'color': Color(0xFFe53935), 'icon': Icons.pie_chart_rounded},
    'goal':      {'label': 'Goals',     'color': Color(0xFF667eea), 'icon': Icons.flag_rounded},
    'recurring': {'label': 'Recurring', 'color': Color(0xFFf77062), 'icon': Icons.repeat_rounded},
    'spending':  {'label': 'Spending',  'color': Color(0xFF43b89c), 'icon': Icons.trending_up_rounded},
    'tip':       {'label': 'Tips',      'color': Color(0xFFa18cd1), 'icon': Icons.lightbulb_rounded},
  };

  Color _typeColor(String type) =>
      (_typeConfig[type]?['color'] as Color?) ?? Colors.grey;

  IconData _typeIcon(String type) =>
      (_typeConfig[type]?['icon'] as IconData?) ?? Icons.notifications_rounded;

  Color _priorityColor(int p) {
    switch (p) {
      case 3: return Colors.red;
      case 2: return Colors.orange;
      case 1: return const Color(0xFF667eea);
      default: return Colors.green;
    }
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 3: return 'URGENT';
      case 2: return 'HIGH';
      case 1: return 'MEDIUM';
      default: return 'LOW';
    }
  }

  // ── Refresh notifications ──────────────────────────────────────────────────
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final count = await _svc.generateNotifications();
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            count > 0
                ? '✅ $count notification${count > 1 ? 's' : ''} updated'
                : '✅ Everything looks good!',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to refresh: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Delete notification ────────────────────────────────────────────────────
  Future<void> _delete(AppNotification n) async {
    await _svc.delete(n.id);
    HapticFeedback.mediumImpact();
  }

  // ── Clear all ──────────────────────────────────────────────────────────────
  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications'),
        content:
            const Text('Delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear All',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.clearAll();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-generate on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(children: [
          const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // Unread badge
          StreamBuilder<int>(
            stream: _svc.getUnreadCount(),
            builder: (_, snap) {
              final n = snap.data ?? 0;
              if (n == 0) return const SizedBox();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$n',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              );
            },
          ),
        ]),
        backgroundColor:
            isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF667eea))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Check now',
              onPressed: _refresh,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) async {
              if (v == 'read_all') await _svc.markAllRead();
              if (v == 'clear')    await _clearAll();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'read_all',
                child: Row(children: [
                  Icon(Icons.done_all_rounded,
                      size: 16, color: Color(0xFF667eea)),
                  SizedBox(width: 10),
                  Text('Mark All Read'),
                ]),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(children: [
                  Icon(Icons.delete_sweep_rounded,
                      size: 16, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Clear All',
                      style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter chips ─────────────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('all', '🔔 All', isDark),
              const SizedBox(width: 8),
              _filterChip('budget',    '📊 Budget',    isDark),
              const SizedBox(width: 8),
              _filterChip('goal',      '🎯 Goals',     isDark),
              const SizedBox(width: 8),
              _filterChip('recurring', '🔁 Recurring', isDark),
              const SizedBox(width: 8),
              _filterChip('spending',  '💡 Spending',  isDark),
            ]),
          ),
        ),

        // ── Notification list ─────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppNotification>>(
            stream: _svc.getNotifications(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF667eea)));
              }

              var notifs = snap.data ?? [];

              // Apply filter
              if (_filter != 'all') {
                notifs =
                    notifs.where((n) => n.type == _filter).toList();
              }

              if (notifs.isEmpty) {
                return _emptyState(isDark);
              }

              // Separate unread / read
              final unread = notifs.where((n) => !n.isRead).toList();
              final read   = notifs.where((n) => n.isRead).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  if (unread.isNotEmpty) ...[
                    _sectionLabel('New', unread.length, isDark),
                    const SizedBox(height: 8),
                    ...unread.map((n) => _notifCard(n, isDark)),
                    const SizedBox(height: 16),
                  ],
                  if (read.isNotEmpty) ...[
                    _sectionLabel('Earlier', read.length, isDark),
                    const SizedBox(height: 8),
                    ...read.map((n) => _notifCard(n, isDark)),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Notification card ──────────────────────────────────────────────────────
  Widget _notifCard(AppNotification n, bool isDark) {
    final tColor = _typeColor(n.type);
    final pColor = _priorityColor(n.priority);
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.red),
      ),
      onDismissed: (_) => _delete(n),
      child: GestureDetector(
        onTap: () async {
          if (!n.isRead) await _svc.markRead(n.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isRead
                  ? Colors.transparent
                  : pColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(n.isRead ? 0.03 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji + type indicator
                Stack(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: tColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(n.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  if (!n.isRead)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: pColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: card, width: 1.5),
                        ),
                      ),
                    ),
                ]),

                const SizedBox(width: 12),

                // Content
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(n.title,
                          style: TextStyle(
                            fontWeight: n.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 13,
                            color: n.isRead
                                ? (isDark ? Colors.white60 : Colors.black54)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Priority badge
                      if (n.priority >= 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _priorityLabel(n.priority),
                            style: TextStyle(
                                color: pColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ]),

                    const SizedBox(height: 4),

                    Text(n.body,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white54 : Colors.black54,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    Row(children: [
                      // Type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(_typeIcon(n.type),
                              size: 10, color: tColor),
                          const SizedBox(width: 3),
                          Text(
                            (_typeConfig[n.type]?['label']
                                    as String?) ??
                                n.type,
                            style: TextStyle(
                                color: tColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      // Time
                      Text(
                        _timeAgo(n.createdAt),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ]),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _filterChip(String value, String label, bool isDark) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF667eea)
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _sectionLabel(String label, int count, bool isDark) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.bold)),
        ),
      ]);

  Widget _emptyState(bool isDark) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('All Clear!',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _filter == 'all'
                ? 'No alerts right now.\nTap refresh to check.'
                : 'No ${_filter} notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}