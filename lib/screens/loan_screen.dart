// lib/screens/loan_screen.dart
// Loan & EMI Manager — list, detail, amortization, prepayment simulator
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../services/loan_service.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v)  => _inr.format(v.abs());
String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN — Loan list
// ════════════════════════════════════════════════════════════════════════════
class LoanScreen extends StatelessWidget {
  const LoanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc    = LoanService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Loan & EMI Manager',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context, null, isDark),
            tooltip: 'Add loan',
          ),
        ],
      ),
      body: StreamBuilder<List<LoanModel>>(
        stream: svc.getLoans(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final loans = snap.data ?? [];
          if (loans.isEmpty) return _EmptyState(
              onAdd: () => _showAddSheet(context, null, isDark));

          final active   = loans.where((l) => l.isActive).toList();
          final closed   = loans.where((l) => !l.isActive).toList();
          final totalEmi = active.fold(0.0, (s, l) => s + l.emi);
          final totalOut = active.fold(0.0, (s, l) => s + l.outstandingBalance);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary banner ───────────────────────────────────────────
              _SummaryBanner(
                  totalEmi: totalEmi,
                  totalOutstanding: totalOut,
                  activeCount: active.length,
                  isDark: isDark),
              const SizedBox(height: 20),

              // ── Active loans ─────────────────────────────────────────────
              if (active.isNotEmpty) ...[
                _sectionHead('Active Loans (${active.length})', isDark),
                const SizedBox(height: 10),
                ...active.map((l) => _LoanCard(
                  loan: l, svc: svc, isDark: isDark,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => _LoanDetailScreen(
                              loan: l, svc: svc))),
                  onEdit:   () => _showAddSheet(context, l, isDark),
                  onDelete: () => _confirmDelete(context, l, svc),
                )),
              ],

              // ── Closed loans ─────────────────────────────────────────────
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionHead('Closed Loans (${closed.length})', isDark),
                const SizedBox(height: 10),
                ...closed.map((l) => _LoanCard(
                  loan: l, svc: svc, isDark: isDark, closed: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => _LoanDetailScreen(
                              loan: l, svc: svc))),
                  onEdit:   () => _showAddSheet(context, l, isDark),
                  onDelete: () => _confirmDelete(context, l, svc),
                )),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, null, isDark),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Loan',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Add/Edit sheet ────────────────────────────────────────────────────────
  static void _showAddSheet(
      BuildContext ctx, LoanModel? existing, bool isDark) {
    final svc = LoanService();
    LoanType type  = existing?.type ?? LoanType.home;
    final nameCtrl  = TextEditingController(text: existing?.name  ?? '');
    final prinCtrl  = TextEditingController(
        text: existing != null
            ? existing.principal.toStringAsFixed(0) : '');
    final rateCtrl  = TextEditingController(
        text: existing != null
            ? existing.annualRate.toStringAsFixed(2) : '');
    final tenCtrl   = TextEditingController(
        text: existing != null
            ? existing.tenureMonths.toString() : '');
    final lenderCtrl = TextEditingController(
        text: existing?.lenderName   ?? '');
    final accCtrl    = TextEditingController(
        text: existing?.accountNumber ?? '');
    final noteCtrl   = TextEditingController(
        text: existing?.note ?? '');
    DateTime startDate = existing?.startDate ?? DateTime.now();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        // Live EMI preview
        final p = double.tryParse(prinCtrl.text) ?? 0;
        final r = double.tryParse(rateCtrl.text) ?? 0;
        final n = int.tryParse(tenCtrl.text)     ?? 0;
        double previewEmi = 0;
        if (p > 0 && r > 0 && n > 0) {
          final mr   = r / 12 / 100;
          double powN = 1;
          for (int i = 0; i < n; i++) powN *= (1 + mr);
          previewEmi = p * mr * powN / (powN - 1);
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  children: [
                Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                Text(existing == null ? 'Add Loan' : 'Edit Loan',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Loan type chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: LoanType.values.map((t) {
                      final sel = type == t;
                      return GestureDetector(
                        onTap: () => setSheet(() => type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.color.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? t.color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text('${t.emoji} ${t.label}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? t.color : Colors.grey,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                _tf(nameCtrl, 'Loan Name *  (e.g. SBI Home Loan)',
                    isDark, cap: TextCapitalization.words),
                const SizedBox(height: 12),

                // Principal + Rate row
                Row(children: [
                  Expanded(child: _tf(prinCtrl, 'Loan Amount *',
                      isDark, prefix: '₹ ', num: true,
                      onChanged: (_) => setSheet(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(rateCtrl, 'Interest Rate % *',
                      isDark, suffix: '%', num: true,
                      onChanged: (_) => setSheet(() {}))),
                ]),
                const SizedBox(height: 12),

                // Tenure + Start date row
                Row(children: [
                  Expanded(child: _tf(tenCtrl, 'Tenure (months) *',
                      isDark, num: true,
                      onChanged: (_) => setSheet(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2040),
                      );
                      if (d != null) setSheet(() => startDate = d);
                    },
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                        border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white54 : Colors.grey[500]),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Date',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500])),
                            Text(
                              DateFormat('d MMM y').format(startDate),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          ],
                        ),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),

                // Lender + Account
                Row(children: [
                  Expanded(child: _tf(lenderCtrl, 'Lender Name', isDark,
                      cap: TextCapitalization.words)),
                  const SizedBox(width: 10),
                  Expanded(child: _tf(accCtrl, 'Account No.', isDark)),
                ]),
                const SizedBox(height: 12),
                _tf(noteCtrl, 'Note (optional)', isDark),
                const SizedBox(height: 16),

                // Live EMI preview
                if (previewEmi > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF667eea)
                              .withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Text('📅',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Monthly EMI',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF667eea))),
                          Text(_f(previewEmi),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF667eea))),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total Interest',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500])),
                          Text(_f(previewEmi *
                                  (int.tryParse(tenCtrl.text) ?? 0) -
                              (double.tryParse(prinCtrl.text) ?? 0)),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange)),
                        ],
                      ),
                    ]),
                  ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          prinCtrl.text.isEmpty ||
                          rateCtrl.text.isEmpty ||
                          tenCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Fill all required fields')));
                        return;
                      }
                      final loan = LoanModel(
                        id:           existing?.id,
                        userId:       '',
                        name:         nameCtrl.text.trim(),
                        type:         type,
                        principal:    double.tryParse(
                                          prinCtrl.text) ?? 0,
                        annualRate:   double.tryParse(
                                          rateCtrl.text) ?? 0,
                        tenureMonths: int.tryParse(
                                          tenCtrl.text) ?? 12,
                        startDate:    startDate,
                        extraPayments: existing?.extraPayments ?? 0,
                        lenderName:   lenderCtrl.text.trim().isEmpty
                            ? null : lenderCtrl.text.trim(),
                        accountNumber: accCtrl.text.trim().isEmpty
                            ? null : accCtrl.text.trim(),
                        note:         noteCtrl.text.trim().isEmpty
                            ? null : noteCtrl.text.trim(),
                        isActive:     existing?.isActive ?? true,
                      );
                      if (existing == null) {
                        await svc.addLoan(loan);
                      } else {
                        await svc.updateLoan(loan);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      existing == null ? 'Add Loan' : 'Save Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  static Widget _tf(
    TextEditingController ctrl,
    String label,
    bool isDark, {
    String? prefix, String? suffix, bool num = false,
    TextCapitalization cap = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: num
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: num
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        textCapitalization: cap,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixText: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
        ),
        style: const TextStyle(fontSize: 13),
      );

  static Future<void> _confirmDelete(
      BuildContext ctx, LoanModel loan, LoanService svc) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Loan'),
        content: Text('Delete "${loan.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && loan.id != null) await svc.deleteLoan(loan.id!);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOAN CARD (list item)
// ════════════════════════════════════════════════════════════════════════════
class _LoanCard extends StatelessWidget {
  final LoanModel    loan;
  final LoanService  svc;
  final bool         isDark;
  final bool         closed;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LoanCard({
    required this.loan,   required this.svc,
    required this.isDark, this.closed = false,
    required this.onTap,  required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg   = isDark ? const Color(0xFF1E2530) : Colors.white;
    final color    = loan.type.color;
    final pct      = loan.progressPct;
    final barColor = pct >= 0.9
        ? Colors.green : (pct >= 0.5 ? const Color(0xFF667eea) : Colors.orange);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: closed ? cardBg.withOpacity(0.6) : cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            // Icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(loan.type.emoji,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  loan.lenderName ?? loan.type.label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
              ],
            )),
            if (closed)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('CLOSED',
                    style: TextStyle(
                        fontSize: 9, color: Colors.green,
                        fontWeight: FontWeight.bold)),
              )
            else
              Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text(_f(loan.emi),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, color: color)),
                Text('/month', style: TextStyle(
                    fontSize: 10, color: Colors.grey[500])),
              ]),

            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey[400]),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
                if (v == 'close')  svc.closeLoan(loan.id!);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: Text('Edit')),
                if (loan.isActive)
                  const PopupMenuItem(value: 'close',
                      child: Text('Mark as Closed')),
                const PopupMenuItem(value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(children: [
            _stat('Outstanding', _f(loan.outstandingBalance),
                Colors.red.shade400),
            const Spacer(),
            _stat('Principal', _f(loan.principal), Colors.grey),
            const Spacer(),
            _stat('${loan.monthsRemaining}mo left', '',
                Colors.grey, sub: true),
          ]),

          // End date
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Ends ${DateFormat('MMM yyyy').format(loan.expectedEndDate)}  ·  '
              '${(pct * 100).toStringAsFixed(0)}% paid',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String val, Color col,
      {bool sub = false}) =>
      Column(children: [
        Text(sub ? label : val,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: sub ? 12 : 13,
                color: col)),
        if (!sub) Text(label, style: TextStyle(
            fontSize: 10, color: Colors.grey[500])),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// DETAIL SCREEN — amortization + prepayment
// ════════════════════════════════════════════════════════════════════════════
class _LoanDetailScreen extends StatefulWidget {
  final LoanModel   loan;
  final LoanService svc;
  const _LoanDetailScreen({required this.loan, required this.svc});
  @override
  State<_LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<_LoanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _prepCtrl = TextEditingController();
  PrepaymentResult? _prepResult;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); _prepCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;
    final loan    = widget.loan;
    final color   = loan.type.color;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(loan.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: color,
          labelColor: color,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Schedule'),
            Tab(text: 'Prepayment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(loan: loan, cardBg: cardBg,
              isDark: isDark, svc: widget.svc),
          _ScheduleTab(loan: loan, cardBg: cardBg, isDark: isDark),
          _PrepaymentTab(loan: loan, cardBg: cardBg, isDark: isDark,
              svc: widget.svc),
        ],
      ),
    );
  }
}

// ── Detail: Overview ──────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final LoanModel loan; final Color cardBg;
  final bool isDark;    final LoanService svc;
  const _OverviewTab({required this.loan, required this.cardBg,
      required this.isDark, required this.svc});

  @override
  Widget build(BuildContext context) {
    final color = loan.type.color;
    final pct   = loan.progressPct;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(loan.type.emoji,
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.name, style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
                  if (loan.lenderName != null)
                    Text(loan.lenderName!, style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text(_f(loan.emi), style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 22)),
                Text('per month', style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('${(pct * 100).toStringAsFixed(0)}% paid',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12)),
              const Spacer(),
              Text(
                '${loan.monthsElapsed} of ${loan.tenureMonths} months',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // Stats grid
        _grid([
          _gridCell('Loan Amount',   _f(loan.principal),
              Icons.account_balance_rounded, Colors.blue),
          _gridCell('Outstanding',   _f(loan.outstandingBalance),
              Icons.warning_amber_rounded, Colors.red),
          _gridCell('Total Interest',_f(loan.totalInterest),
              Icons.percent_rounded, Colors.orange),
          _gridCell('Interest Rate', '${loan.annualRate}% p.a.',
              Icons.trending_up_rounded, Colors.purple),
          _gridCell('Tenure',        '${loan.tenureMonths} months',
              Icons.calendar_month_rounded, Colors.teal),
          _gridCell('End Date',
              DateFormat('MMM yyyy').format(loan.expectedEndDate),
              Icons.event_rounded, Colors.green),
        ], cardBg, isDark),
        const SizedBox(height: 20),

        // Payment breakdown
        _PayBreakdown(loan: loan, cardBg: cardBg, isDark: isDark),
        const SizedBox(height: 20),

        // Loan details
        if (loan.accountNumber != null || loan.note != null)
          _DetailsCard(loan: loan, cardBg: cardBg, isDark: isDark),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _grid(List<Widget> cells, Color bg, bool dark) =>
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: cells,
      );

  Widget _gridCell(String label, String val,
      IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(val, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(
                  fontSize: 10, color: Colors.grey[500])),
            ],
          )),
        ]),
      );
}

// ── Payment breakdown widget ──────────────────────────────────────────────────
class _PayBreakdown extends StatelessWidget {
  final LoanModel loan; final Color cardBg; final bool isDark;
  const _PayBreakdown({required this.loan,
      required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final princPaid  = loan.principalPaid;
    final intPaid    = loan.interestPaid;
    final princLeft  = (loan.principal - princPaid).clamp(0.0, loan.principal).toDouble();
    final intLeft    = (loan.totalInterest - intPaid)
        .clamp(0.0, loan.totalInterest);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Payment Breakdown',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 16),
        _bar('Principal Paid',     princPaid,
            loan.principal,  Colors.blue),
        const SizedBox(height: 10),
        _bar('Interest Paid',      intPaid,
            loan.totalInterest, Colors.orange),
        const SizedBox(height: 10),
        _bar('Principal Remaining',princLeft,
            loan.principal,  Colors.blue.withOpacity(0.3)),
        const SizedBox(height: 10),
        _bar('Interest Remaining', intLeft,
            loan.totalInterest, Colors.orange.withOpacity(0.3)),
      ]),
    );
  }

  Widget _bar(String label, double val, double max, Color color) {
    final pct = max > 0 ? (val / max).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12))),
        Text(_f(val), style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 5,
          backgroundColor: Colors.grey.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

// ── Details card ──────────────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  final LoanModel loan; final Color cardBg; final bool isDark;
  const _DetailsCard({required this.loan,
      required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Loan Details',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (loan.accountNumber != null)
            _row('Account No.', loan.accountNumber!),
          if (loan.lenderName != null)
            _row('Lender', loan.lenderName!),
          _row('Start Date',
              DateFormat('d MMMM yyyy').format(loan.startDate)),
          if (loan.note != null) _row('Note', loan.note!),
        ]),
      );

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(k,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
      Expanded(child: Text(v,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ── Detail: Amortization Schedule ────────────────────────────────────────────
class _ScheduleTab extends StatelessWidget {
  final LoanModel loan; final Color cardBg; final bool isDark;
  const _ScheduleTab({required this.loan,
      required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = loan.schedule;

    return Column(children: [
      // Header
      Container(
        color: cardBg,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        child: Row(children: [
          _hCell('Month', flex: 2),
          _hCell('EMI'),
          _hCell('Principal'),
          _hCell('Interest'),
          _hCell('Balance'),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final row = rows[i];
            final bg  = row.isPaid
                ? Colors.green.withOpacity(0.04)
                : (i % 2 == 0
                    ? cardBg
                    : (isDark
                        ? Colors.white.withOpacity(0.02)
                        : Colors.grey.shade50));
            return Container(
              color: bg,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              child: Row(children: [
                Expanded(flex: 2, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row.month}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: row.isPaid
                                ? Colors.green : null)),
                    Text(DateFormat('MMM yy').format(row.date),
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey[500])),
                  ],
                )),
                _dCell(_f(row.emi),     null),
                _dCell(_f(row.principal), Colors.blue),
                _dCell(_f(row.interest), Colors.orange),
                _dCell(row.balance < 1
                    ? '✅' : _f(row.balance),
                    row.balance < 1 ? null : Colors.red.shade400),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _hCell(String t, {int flex = 1}) => Expanded(
      flex: flex,
      child: Text(t,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10, color: Colors.grey[500])));

  Widget _dCell(String v, Color? c) => Expanded(
      child: Text(v,
          style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis));
}

// ── Detail: Prepayment simulator ─────────────────────────────────────────────
class _PrepaymentTab extends StatefulWidget {
  final LoanModel loan; final Color cardBg;
  final bool isDark;    final LoanService svc;
  const _PrepaymentTab({required this.loan, required this.cardBg,
      required this.isDark, required this.svc});
  @override
  State<_PrepaymentTab> createState() => _PrepaymentTabState();
}

class _PrepaymentTabState extends State<_PrepaymentTab> {
  final _simCtrl   = TextEditingController();
  final _payCtrl   = TextEditingController();
  PrepaymentResult? _result;

  @override
  void dispose() {
    _simCtrl.dispose(); _payCtrl.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loan    = widget.loan;
    final cardBg  = widget.cardBg;
    final isDark  = widget.isDark;
    final color   = loan.type.color;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Current Status',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _row2('Outstanding Balance',
                _f(loan.outstandingBalance), Colors.red),
            _row2('Months Remaining',
                '${loan.monthsRemaining} months', Colors.orange),
            _row2('Interest Remaining',
                _f(loan.remainingInterest()), Colors.orange),
          ]),
        ),
        const SizedBox(height: 20),

        // Simulator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('🔮', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Prepayment Simulator',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            Text('See how a lump-sum payment reduces tenure & interest',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 16),
            TextField(
              controller: _simCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: InputDecoration(
                labelText: 'Extra Payment Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(_simCtrl.text);
                  if (amt == null || amt <= 0) return;
                  setState(() {
                    _result = loan.simulate(amt);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simulate',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _resultRow('✅ New Tenure',
                  '${_result!.newMonths} months',
                  Colors.green),
              _resultRow('📅 Months Saved',
                  '${_result!.savedMonths} months',
                  color),
              _resultRow('💰 Interest Saved',
                  _f(_result!.savedInterest),
                  Colors.green),
              _resultRow('🏁 New End Date',
                  DateFormat('MMM yyyy')
                      .format(_result!.newEndDate),
                  Colors.blue),
            ],
          ]),
        ),
        const SizedBox(height: 20),

        // Record actual prepayment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('💳', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Record Prepayment',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            Text('Add an actual prepayment made to the bank',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 16),
            TextField(
              controller: _payCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton(
                onPressed: () async {
                  final amt = double.tryParse(_payCtrl.text);
                  if (amt == null || amt <= 0) return;
                  await widget.svc.recordPrepayment(widget.loan, amt);
                  _payCtrl.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(
                          '${_f(amt)} prepayment recorded ✅'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Record Prepayment',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (widget.loan.extraPayments > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Total prepayments recorded: '
                '${_f(widget.loan.extraPayments)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.green[600],
                    fontWeight: FontWeight.w600),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _row2(String k, String v, Color col) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(k,
          style: const TextStyle(fontSize: 13))),
      Text(v, style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13, color: col)),
    ]),
  );

  Widget _resultRow(String label, String val, Color col) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13))),
          Text(val, style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14, color: col)),
        ]),
      );
}

// ── Summary banner ────────────────────────────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final double totalEmi, totalOutstanding;
  final int activeCount;
  final bool isDark;
  const _SummaryBanner({
    required this.totalEmi,         required this.totalOutstanding,
    required this.activeCount,      required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.35),
            blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        const Text('🏦', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$activeCount Active Loan${activeCount == 1 ? '' : 's'}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12)),
            Text(_f(totalEmi),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 24)),
            const Text('Combined Monthly EMI',
                style: TextStyle(
                    color: Colors.white70, fontSize: 11)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_f(totalOutstanding),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('Total Outstanding',
              style: TextStyle(
                  color: Colors.white70, fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      const Text('🏦', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      const Text('No Loans Yet',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Add your loans to track EMI\nand plan prepayments',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500])),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add First Loan'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12)),
      ),
    ]),
  );
}

Widget _sectionHead(String t, bool isDark) => Text(t,
    style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87));