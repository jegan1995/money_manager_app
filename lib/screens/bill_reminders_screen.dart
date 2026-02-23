import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_reminder_model.dart';
import '../models/account_model.dart';
import '../services/bill_reminder_service.dart';
import '../services/account_service.dart';
import 'add_bill_reminder_screen.dart';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});

  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen>
    with SingleTickerProviderStateMixin {
  final _service = BillReminderService();
  final _accountService = AccountService();
  late TabController _tabController;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _accountService.getAccounts().listen((list) {
      if (mounted) setState(() => _accounts = list);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _accountName(String? id) {
    if (id == null) return '';
    try {
      return _accounts.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return '';
    }
  }

  // ── Mark as Paid ─────────────────────────────────────────────────────────────
  Future<void> _markPaid(BillReminderModel bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Paid?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill: ${bill.name}'),
            Text('Amount: ₹${bill.amount.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            if (bill.repeatType == 'one_time')
              const Text('This is a one-time bill — it will be deactivated.',
                  style: TextStyle(fontSize: 12, color: Colors.orange))
            else
              Text(
                'Next due will be calculated automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Mark Paid',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.markAsPaid(bill);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${bill.name} marked as paid!',
                style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        ));
      }
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────────
  Future<void> _delete(BillReminderModel bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill Reminder?'),
        content: Text('Delete "${bill.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteBillReminder(bill.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Inactive'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddBillReminderScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<BillReminderModel>>(
        stream: _service.getBillReminders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final active = all.where((b) => b.isActive).toList();
          final inactive = all.where((b) => !b.isActive).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTab(active, theme),
              _buildInactiveTab(inactive, theme),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddBillReminderScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }

  Widget _buildActiveTab(List<BillReminderModel> bills, ThemeData theme) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No bill reminders yet',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Tap + to add electricity, rent, EMI etc.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Group by urgency
    final overdue = bills.where((b) => b.daysUntilDue < 0).toList();
    final today = bills.where((b) => b.daysUntilDue == 0).toList();
    final soon = bills.where((b) => b.daysUntilDue > 0 && b.daysUntilDue <= 7).toList();
    final upcoming = bills.where((b) => b.daysUntilDue > 7).toList();

    // Summary card total
    final totalDueSoon = bills
        .where((b) => b.daysUntilDue <= 7)
        .fold(0.0, (sum, b) => sum + b.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        if (bills.isNotEmpty) ...[
          _buildSummaryCard(bills, totalDueSoon, theme),
          const SizedBox(height: 16),
        ],

        if (overdue.isNotEmpty) ...[
          _sectionHeader('⚠️ Overdue', Colors.red),
          ...overdue.map((b) => _buildBillCard(b, theme)),
        ],
        if (today.isNotEmpty) ...[
          _sectionHeader('🔴 Due Today', Colors.red),
          ...today.map((b) => _buildBillCard(b, theme)),
        ],
        if (soon.isNotEmpty) ...[
          _sectionHeader('🟠 Due This Week', Colors.orange),
          ...soon.map((b) => _buildBillCard(b, theme)),
        ],
        if (upcoming.isNotEmpty) ...[
          _sectionHeader('🟢 Upcoming', Colors.green),
          ...upcoming.map((b) => _buildBillCard(b, theme)),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(
      List<BillReminderModel> bills, double totalDueSoon, ThemeData theme) {
    final overdueCount = bills.where((b) => b.daysUntilDue <= 0).length;
    final totalMonthly =
        bills.where((b) => b.repeatType == 'monthly').fold(0.0, (s, b) => s + b.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overdueCount > 0
              ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdueCount > 0 ? Icons.warning_rounded : Icons.notifications_active,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                overdueCount > 0
                    ? '$overdueCount bill${overdueCount > 1 ? 's' : ''} overdue!'
                    : 'Bill Summary',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                    'Due This Week', '₹${totalDueSoon.toStringAsFixed(0)}'),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _summaryItem(
                    'Monthly Total', '₹${totalMonthly.toStringAsFixed(0)}'),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _summaryItem('Bills', '${bills.length}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildBillCard(BillReminderModel bill, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final d = bill.daysUntilDue;

    Color statusColor;
    if (d < 0) {
      statusColor = Colors.red;
    } else if (d == 0) {
      statusColor = Colors.red;
    } else if (d <= 3) {
      statusColor = Colors.orange;
    } else if (d <= 7) {
      statusColor = const Color(0xFFF9A825);
    } else {
      statusColor = Colors.green;
    }

    final accountName = _accountName(bill.accountId);

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _delete(bill);
        return false; // We handle deletion ourselves
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddBillReminderScreen(bill: bill)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Category icon circle
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForCategory(bill.category),
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bill.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (bill.isAutoPay)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('AUTO',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bill.statusLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (accountName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.account_balance_wallet,
                                size: 11, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Text(accountName,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            bill.nextDueDate != null
                                ? DateFormat('d MMM yyyy')
                                    .format(bill.nextDueDate!)
                                : 'Day ${bill.dueDayOfMonth} of month',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.repeat, size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            bill.repeatType == 'monthly'
                                ? 'Monthly'
                                : bill.repeatType == 'yearly'
                                    ? 'Yearly'
                                    : 'One-time',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount + pay button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${bill.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _markPaid(bill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '✓ Paid',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveTab(
      List<BillReminderModel> bills, ThemeData theme) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No inactive bills',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (_, i) {
        final bill = bills[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: Icon(_iconForCategory(bill.category),
                color: Colors.grey[400]),
            title: Text(bill.name,
                style: TextStyle(color: Colors.grey[600])),
            subtitle: Text('₹${bill.amount.toStringAsFixed(0)} • ${bill.repeatType}'),
            trailing: Switch(
              value: false,
              onChanged: (_) =>
                  _service.toggleActive(bill.id, true),
              activeColor: Colors.green,
            ),
          ),
        );
      },
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Rent':
        return Icons.home;
      case 'Insurance':
        return Icons.shield;
      case 'Loan / EMI':
        return Icons.account_balance;
      case 'Subscription':
        return Icons.subscriptions;
      case 'Education':
        return Icons.school;
      case 'Healthcare':
        return Icons.local_hospital;
      case 'Tax':
        return Icons.percent;
      default:
        return Icons.receipt_long;
    }
  }
}