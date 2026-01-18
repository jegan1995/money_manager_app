import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import '../services/goal_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _goalService = GoalService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Goals'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _goalService.getGoals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 24),
                  Text('No goals yet',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Tap + to set your first financial goal',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddGoalDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Goal'),
                  ),
                ],
              ),
            );
          }

          final goals = snapshot.data!.docs
              .map((doc) => GoalModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _buildGoalCard(goal);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final progressColor = goal.isCompleted
        ? Colors.green
        : (goal.isOverdue ? Colors.red : Colors.blue);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showGoalDetails(goal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (goal.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            goal.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${goal.currentAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${goal.progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Target: ${DateFormat('MMM d, yyyy').format(goal.targetDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (!goal.isCompleted)
                    Text(
                      goal.isOverdue
                          ? 'Overdue'
                          : '${goal.daysRemaining} days left',
                      style: TextStyle(
                        fontSize: 12,
                        color: goal.isOverdue ? Colors.red : Colors.grey[600],
                        fontWeight: goal.isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetAmountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Financial Goal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Goal Name *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Emergency Fund',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target Amount *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Target Date'),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(targetDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            targetDate = date;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        targetAmountController.text.isEmpty) {
                      return;
                    }

                    final goal = GoalModel(
                      name: nameController.text,
                      targetAmount: double.parse(targetAmountController.text),
                      targetDate: targetDate,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                    );

                    try {
                      await _goalService.addGoal(goal);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Goal added'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGoalDetails(GoalModel goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(goal.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current: ₹${goal.currentAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Target: ₹${goal.targetAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (!goal.isCompleted) ...[
                const Text('Add Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Goal'),
                    content: const Text('Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await _goalService.deleteGoal(goal.id!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            if (!goal.isCompleted) ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (amountController.text.isEmpty) return;

                  try {
                    await _goalService.addAmountToGoal(
                      goal.id!,
                      double.parse(amountController.text),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Amount added to goal'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ],
        );
      },
    );
  }
}
