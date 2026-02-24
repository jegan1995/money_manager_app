import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Inputs ─────────────────────────────────────────────────────────────────
  final _amountCtrl = TextEditingController();
  final _rateCtrl   = TextEditingController();
  final _tenureCtrl = TextEditingController();

  String _tenureType = 'Years'; // Years / Months
  String _loanType   = 'Home Loan';

  // ── Results ────────────────────────────────────────────────────────────────
  double? _emi;
  double? _totalPayable;
  double? _totalInterest;
  List<_AmortRow> _schedule = [];
  bool _showSchedule = false;

  static const _loanTypes = [
    'Home Loan', 'Car Loan', 'Personal Loan',
    'Education Loan', 'Business Loan', 'Gold Loan',
  ];

  static const _loanDefaults = {
    'Home Loan':      {'rate': '8.5',  'tenure': '20'},
    'Car Loan':       {'rate': '9.0',  'tenure': '5'},
    'Personal Loan':  {'rate': '14.0', 'tenure': '3'},
    'Education Loan': {'rate': '10.5', 'tenure': '10'},
    'Business Loan':  {'rate': '12.0', 'tenure': '5'},
    'Gold Loan':      {'rate': '7.5',  'tenure': '2'},
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _applyDefaults('Home Loan');
  }

  @override
  void dispose() {
    _tab.dispose();
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  void _applyDefaults(String type) {
    final d = _loanDefaults[type]!;
    _rateCtrl.text   = d['rate']!;
    _tenureCtrl.text = d['tenure']!;
    _tenureType      = 'Years';
  }

  void _calculate() {
    final P = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    final r = double.tryParse(_rateCtrl.text);
    final t = double.tryParse(_tenureCtrl.text);

    if (P == null || r == null || t == null || P <= 0 || r <= 0 || t <= 0) {
      _snack('Please fill all fields correctly');
      return;
    }

    final months = _tenureType == 'Years' ? (t * 12).round() : t.round();
    final monthlyRate = r / 12 / 100;

    final emi = P * monthlyRate * pow(1 + monthlyRate, months) /
        (pow(1 + monthlyRate, months) - 1);

    final total    = emi * months;
    final interest = total - P;

    // Build amortization schedule
    final schedule = <_AmortRow>[];
    double balance = P;
    final now = DateTime.now();

    for (int i = 1; i <= months; i++) {
      final intPart  = balance * monthlyRate;
      final prinPart = emi - intPart;
      balance -= prinPart;
      final date = DateTime(now.year, now.month + i, 1);
      schedule.add(_AmortRow(
        month:     i,
        date:      date,
        emi:       emi,
        principal: prinPart,
        interest:  intPart,
        balance:   balance < 0 ? 0 : balance,
      ));
    }

    setState(() {
      _emi           = emi;
      _totalPayable  = total;
      _totalInterest = interest;
      _schedule      = schedule;
      _showSchedule  = false;
    });

    FocusScope.of(context).unfocus();
  }

  void _reset() {
    setState(() {
      _amountCtrl.clear();
      _applyDefaults(_loanType);
      _emi = _totalPayable = _totalInterest = null;
      _schedule.clear();
      _showSchedule = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  String _fmt(double v) => '₹${NumberFormat('#,##,##0').format(v.round())}';
  String _fmtD(double v) => '₹${NumberFormat('#,##,##0.##').format(v)}';

  Color get _loanColor {
    switch (_loanType) {
      case 'Home Loan':      return const Color(0xFF1565C0);
      case 'Car Loan':       return const Color(0xFF00838F);
      case 'Personal Loan':  return const Color(0xFF6A1B9A);
      case 'Education Loan': return const Color(0xFF2E7D32);
      case 'Business Loan':  return const Color(0xFFE65100);
      case 'Gold Loan':      return const Color(0xFFF9A825);
      default:               return const Color(0xFF1565C0);
    }
  }

  String get _loanEmoji {
    switch (_loanType) {
      case 'Home Loan':      return '🏠';
      case 'Car Loan':       return '🚗';
      case 'Personal Loan':  return '👤';
      case 'Education Loan': return '🎓';
      case 'Business Loan':  return '💼';
      case 'Gold Loan':      return '🥇';
      default:               return '💰';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('EMI Calculator'),
        backgroundColor: _loanColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'Calculator'),
            Tab(icon: Icon(Icons.table_rows), text: 'Schedule'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildCalculatorTab(isDark),
          _buildScheduleTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Calculator ───────────────────────────────────────────────────────
  Widget _buildCalculatorTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Loan type selector
          _buildLoanTypeSelector(isDark),
          const SizedBox(height: 16),

          // Input card
          _buildInputCard(isDark),
          const SizedBox(height: 16),

          // Calculate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate EMI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _loanColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Results
          if (_emi != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(isDark),
            const SizedBox(height: 16),
            _buildBreakdownCard(isDark),
            const SizedBox(height: 16),
            _buildYearlyBreakdown(isDark),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLoanTypeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Type',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey[500])),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _loanTypes.map((type) {
              final selected = type == _loanType;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _loanType = type;
                    _applyDefaults(type);
                    _emi = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? _loanColor : _loanColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _loanColor : _loanColor.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _loanColor),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Loan amount
          _inputField(
            controller: _amountCtrl,
            label: 'Loan Amount',
            prefix: '₹',
            hint: 'e.g. 50,00,000',
            icon: Icons.currency_rupee,
            isNumber: true,
          ),
          const SizedBox(height: 14),

          // Interest rate
          _inputField(
            controller: _rateCtrl,
            label: 'Annual Interest Rate',
            suffix: '% per year',
            hint: 'e.g. 8.5',
            icon: Icons.percent,
            isDecimal: true,
          ),
          const SizedBox(height: 14),

          // Tenure row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _inputField(
                  controller: _tenureCtrl,
                  label: 'Loan Tenure',
                  hint: 'e.g. 20',
                  icon: Icons.calendar_month,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unit',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Years',  label: Text('Yr')),
                        ButtonSegment(value: 'Months', label: Text('Mo')),
                      ],
                      selected: {_tenureType},
                      onSelectionChanged: (s) =>
                          setState(() => _tenureType = s.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) return _loanColor;
                          return null;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) return Colors.white;
                          return null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefix,
    String? suffix,
    bool isNumber  = false,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500])),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : const TextInputType.numberWithOptions(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                isDecimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            prefixIcon: Icon(icon, color: _loanColor, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _loanColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_loanColor, _loanColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _loanColor.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_loanEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(_loanType,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Monthly EMI',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            _fmtD(_emi!),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat('Principal', _fmt(double.parse(
                  _amountCtrl.text.replaceAll(',', '')))),
              _vDivider(),
              _resultStat('Interest', _fmt(_totalInterest!)),
              _vDivider(),
              _resultStat('Total', _fmt(_totalPayable!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      );

  Widget _vDivider() => Container(
      width: 1, height: 30, color: Colors.white24);

  Widget _buildBreakdownCard(bool isDark) {
    final P = double.parse(_amountCtrl.text.replaceAll(',', ''));
    final principalPct = P / _totalPayable! * 100;
    final interestPct  = 100 - principalPct;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),

          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Flexible(
                  flex: principalPct.round(),
                  child: Container(
                      height: 20,
                      color: _loanColor),
                ),
                Flexible(
                  flex: interestPct.round(),
                  child: Container(
                      height: 20,
                      color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _legend(_loanColor, 'Principal',
                  '${principalPct.toStringAsFixed(1)}%'),
              const SizedBox(width: 20),
              _legend(Colors.orange, 'Interest',
                  '${interestPct.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, String pct) => Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label ($pct)',
              style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _buildYearlyBreakdown(bool isDark) {
    // Group schedule by year
    final Map<int, _YearSummary> years = {};
    for (final row in _schedule) {
      final yr = ((row.month - 1) ~/ 12) + 1;
      years[yr] ??= _YearSummary(yr);
      years[yr]!.principal += row.principal;
      years[yr]!.interest  += row.interest;
      years[yr]!.endBalance = row.balance;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Year-wise Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton(
                onPressed: () {
                  _tab.animateTo(1);
                },
                child: Text('Full Schedule',
                    style: TextStyle(color: _loanColor, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Header
          Row(
            children: [
              _th('Year', flex: 1),
              _th('Principal', flex: 2),
              _th('Interest', flex: 2),
              _th('Balance', flex: 2),
            ],
          ),
          const Divider(),

          ...years.values.take(5).map((y) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    _td('Yr ${y.year}', flex: 1, bold: true),
                    _td(_fmt(y.principal), flex: 2, color: _loanColor),
                    _td(_fmt(y.interest),  flex: 2, color: Colors.orange),
                    _td(_fmt(y.endBalance), flex: 2),
                  ],
                ),
              )),

          if (years.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${years.length - 5} more years — see Full Schedule tab',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _th(String t, {required int flex}) => Expanded(
      flex: flex,
      child: Text(t,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500])));

  Widget _td(String t,
          {required int flex, Color? color, bool bold = false}) =>
      Expanded(
          flex: flex,
          child: Text(t,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)));

  // ── Tab 2: Amortization Schedule ───────────────────────────────────────────
  Widget _buildScheduleTab(bool isDark) {
    if (_schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No schedule yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Calculate EMI first to see the schedule',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _loanColor.withOpacity(0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _schedStat('EMI', _fmtD(_emi!)),
              _schedStat('Months', '${_schedule.length}'),
              _schedStat('Total Interest', _fmt(_totalInterest!)),
            ],
          ),
        ),

        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _loanColor,
          child: Row(
            children: [
              _schedHead('Mo', flex: 1),
              _schedHead('EMI', flex: 2),
              _schedHead('Principal', flex: 2),
              _schedHead('Interest', flex: 2),
              _schedHead('Balance', flex: 3),
            ],
          ),
        ),

        // Table rows
        Expanded(
          child: ListView.builder(
            itemCount: _schedule.length,
            itemBuilder: (context, i) {
              final row  = _schedule[i];
              final even = i % 2 == 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                color: even
                    ? (isDark
                        ? const Color(0xFF1A1F28)
                        : Colors.white)
                    : (isDark
                        ? const Color(0xFF1E2530)
                        : const Color(0xFFF8F9FB)),
                child: Row(
                  children: [
                    _schedCell('${row.month}', flex: 1, bold: true),
                    _schedCell(_fmtD(row.emi), flex: 2),
                    _schedCell(_fmtD(row.principal),
                        flex: 2, color: _loanColor),
                    _schedCell(_fmtD(row.interest),
                        flex: 2, color: Colors.orange),
                    _schedCell(_fmt(row.balance), flex: 3),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _schedStat(String label, String value) => Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _loanColor)),
        ],
      );

  Widget _schedHead(String t, {required int flex}) => Expanded(
      flex: flex,
      child: Text(t,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white)));

  Widget _schedCell(String t,
          {required int flex, Color? color, bool bold = false}) =>
      Expanded(
          flex: flex,
          child: Text(t,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)));
}

// ── Data classes ──────────────────────────────────────────────────────────────
class _AmortRow {
  final int month;
  final DateTime date;
  final double emi;
  final double principal;
  final double interest;
  final double balance;

  const _AmortRow({
    required this.month,
    required this.date,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.balance,
  });
}

class _YearSummary {
  final int year;
  double principal = 0;
  double interest  = 0;
  double endBalance = 0;
  _YearSummary(this.year);
}