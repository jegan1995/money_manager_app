import 'package:flutter/material.dart';
import '../models/split_expense_model.dart';
import '../services/split_expense_service.dart';

class AddSplitExpenseScreen extends StatefulWidget {
  const AddSplitExpenseScreen({super.key});

  @override
  State<AddSplitExpenseScreen> createState() => _AddSplitExpenseScreenState();
}

class _AddSplitExpenseScreenState extends State<AddSplitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final SplitExpenseService _service = SplitExpenseService();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<TextEditingController> _nameControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  String _splitMethod = 'equal'; // 'equal' or 'custom'

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Dinner at restaurant',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total Amount',
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Split Between',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            ..._nameControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Person ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    if (_nameControllers.length > 2)
                      IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removePerson(index),
                      ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addPerson,
              icon: const Icon(Icons.add),
              label: const Text('Add Person'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Split Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            RadioListTile(
              title: const Text('Split Equally'),
              value: 'equal',
              groupValue: _splitMethod,
              onChanged: (value) => setState(() => _splitMethod = value!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSplit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Split',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addPerson() {
    setState(() {
      _nameControllers.add(TextEditingController());
    });
  }

  void _removePerson(int index) {
    setState(() {
      _nameControllers[index].dispose();
      _nameControllers.removeAt(index);
    });
  }

  Future<void> _saveSplit() async {
    if (!_formKey.currentState!.validate()) return;

    final totalAmount = double.parse(_amountController.text);
    final names = _nameControllers.map((c) => c.text.trim()).toList();

    List<SplitPerson> splits;
    if (_splitMethod == 'equal') {
      final amountPerPerson = totalAmount / names.length;
      splits = names
          .map((name) => SplitPerson(name: name, amount: amountPerPerson))
          .toList();
    } else {
      // Custom split would need additional UI
      splits = [];
    }

    final expense = SplitExpenseModel(
      id: '',
      userId: '',
      description: _descriptionController.text,
      totalAmount: totalAmount,
      splits: splits,
      date: _selectedDate,
      isSettled: false,
      createdAt: DateTime.now(),
    );

    try {
      await _service.addSplitExpense(expense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split expense created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
