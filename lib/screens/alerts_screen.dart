import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_alert_model.dart';
import '../services/budget_alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final BudgetAlertService _alertService = BudgetAlertService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Alerts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          StreamBuilder<int>(
            stream: _alertService.getUnreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              
              return TextButton.icon(
                onPressed: () async {
                  await _alertService.markAllAsRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All alerts marked as read')),
                    );
                  }
                },
                icon: const Icon(Icons.done_all, color: Colors.white),
                label: const Text(
                  'Mark All Read',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<BudgetAlertModel>>(
        stream: _alertService.getAllAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Budget alerts will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final alerts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _buildAlertCard(alerts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(BudgetAlertModel alert) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (alert.alertType) {
      case 'exceeded':
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade900;
        break;
      case 'critical':
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade400;
        textColor = Colors.orange.shade900;
        break;
      default:
        backgroundColor = Colors.yellow.shade50;
        borderColor = Colors.yellow.shade700;
        textColor = Colors.yellow.shade900;
    }

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _alertService.markAsRead(alert.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Alert dismissed')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: alert.isRead ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: alert.isRead ? Colors.grey.shade300 : borderColor,
            width: alert.isRead ? 1 : 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: alert.isRead ? Colors.grey.shade50 : backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: borderColor.withOpacity(0.2),
              child: Text(
                alert.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            title: Text(
              alert.category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: alert.isRead ? Colors.grey.shade700 : textColor,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  alert.message,
                  style: TextStyle(
                    color: alert.isRead ? Colors.grey.shade600 : textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: alert.percentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  color: alert.percentage >= 100
                      ? Colors.red
                      : alert.percentage >= 90
                          ? Colors.orange
                          : Colors.yellow.shade700,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${alert.spentAmount.toStringAsFixed(0)} / ₹${alert.budgetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: alert.isRead ? Colors.grey.shade600 : textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(alert.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: !alert.isRead
                ? IconButton(
                    icon: const Icon(Icons.done, color: Colors.green),
                    onPressed: () async {
                      await _alertService.markAsRead(alert.id);
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}