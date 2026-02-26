import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../screens/transaction_detail_screen.dart';

class CategoryTransactionsScreen extends StatelessWidget {
  final String category;
  final List<TransactionModel> transactions;
  final Color color;

  const CategoryTransactionsScreen({
    super.key,
    required this.category,
    required this.transactions,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final total   = transactions.fold(0.0, (s, t) => s + t.amount);
    final avgAmt  = transactions.isEmpty ? 0.0 : total / transactions.length;

    // Group by date
    final grouped = <String, List<TransactionModel>>{};
    for (final t in sorted) {
      final key = DateFormat('dd MMM yyyy').format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(category),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Summary header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Total Spent', _fmt(total), Colors.white),
                Container(
                    width: 1, height: 40,
                    color: Colors.white30),
                _statItem('Transactions',
                    transactions.length.toString(), Colors.white),
                Container(
                    width: 1, height: 40,
                    color: Colors.white30),
                _statItem('Average', _fmt(avgAmt), Colors.white),
              ],
            ),
          ),

          // ── Transactions list ────────────────────────────────────────
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No transactions in $category',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: grouped.keys.length,
                    itemBuilder: (ctx, i) {
                      final dateKey =
                          grouped.keys.elementAt(i);
                      final dayTxns = grouped[dateKey]!;
                      final dayTotal = dayTxns.fold(
                          0.0, (s, t) => s + t.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateKey,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[500])),
                                Text(_fmt(dayTotal),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ],
                            ),
                          ),
                          // Transactions for this date
                          ...dayTxns.map((t) => _txnCard(
                              context, t, isDark, color)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _txnCard(BuildContext context, TransactionModel t,
      bool isDark, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: t)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_downward,
                  color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.note ?? t.description ?? t.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (t.subcategory != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t.subcategory!,
                            style: TextStyle(
                                fontSize: 10, color: color)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (t.paymentMethod != null)
                      Text(t.paymentMethod!,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400])),
                  ]),
                ],
              ),
            ),
            Text(
              _fmt(t.amount),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11)),
      ]);

  String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 10000000)
      return '₹${(abs / 10000000).toStringAsFixed(2)}Cr';
    if (abs >= 100000)
      return '₹${(abs / 100000).toStringAsFixed(2)}L';
    return '₹${NumberFormat('#,##,##0').format(abs)}';
  }
}