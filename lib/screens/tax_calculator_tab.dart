// lib/screens/tax_calculator_tab.dart
// Full Indian IT Tax Calculator — FY 2025-26
// Sections: Salary | HRA | Business | Capital Gains | Other Income | Deductions
// Output: New vs Old regime comparison + recommendation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tax_calculator_service.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _inr.format(v);
String _pct(double v) => '${v.toStringAsFixed(1)}%';

class TaxCalculatorTab extends StatefulWidget {
  const TaxCalculatorTab({super.key});
  @override
  State<TaxCalculatorTab> createState() => _TaxCalculatorTabState();
}

class _TaxCalculatorTabState extends State<TaxCalculatorTab> {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _basic   = TextEditingController();
  final _hra     = TextEditingController();
  final _special = TextEditingController();
  final _lta     = TextEditingController();
  final _otherAllow = TextEditingController();
  final _rent    = TextEditingController();
  final _bizNet  = TextEditingController();
  final _presump = TextEditingController();
  final _stcgEq  = TextEditingController();
  final _ltcgEq  = TextEditingController();
  final _stcgOt  = TextEditingController();
  final _ltcgOt  = TextEditingController();
  final _debtMF  = TextEditingController();
  final _fdInt   = TextEditingController();
  final _savInt  = TextEditingController();
  final _div     = TextEditingController();
  final _other   = TextEditingController();
  final _c80c    = TextEditingController();
  final _c80ccd  = TextEditingController();
  final _c80d    = TextEditingController();
  final _c80e    = TextEditingController();
  final _c80g    = TextEditingController();
  final _hlInt   = TextEditingController();
  final _hlPrin  = TextEditingController();

  bool _metro        = false;
  bool _isProfessional = true;
  bool _showResult   = false;
  TaxResult? _result;

  // Section expand states
  final _expanded = <String, bool>{
    'salary': true, 'hra': false, 'business': false,
    'capgains': false, 'other': false, 'deductions': false,
  };

  @override
  void initState() { super.initState(); _loadSaved(); }

  @override
  void dispose() {
    for (final c in [_basic,_hra,_special,_lta,_otherAllow,_rent,
        _bizNet,_presump,_stcgEq,_ltcgEq,_stcgOt,_ltcgOt,_debtMF,
        _fdInt,_savInt,_div,_other,_c80c,_c80ccd,_c80d,_c80e,
        _c80g,_hlInt,_hlPrin]) { c.dispose(); }
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  TaxInput _buildInput() => TaxInput(
    basicSalary:       _v(_basic),
    hra:               _v(_hra),
    specialAllowance:  _v(_special),
    lta:               _v(_lta),
    otherAllowances:   _v(_otherAllow),
    rentPaid:          _v(_rent),
    metroCity:         _metro,
    businessIncome:    _v(_bizNet),
    presumptiveIncome: _v(_presump),
    isProfessional:    _isProfessional,
    stcgEquity:        _v(_stcgEq),
    ltcgEquity:        _v(_ltcgEq),
    stcgOther:         _v(_stcgOt),
    ltcgOther:         _v(_ltcgOt),
    debtFundGains:     _v(_debtMF),
    fdInterest:        _v(_fdInt),
    savingsInterest:   _v(_savInt),
    dividends:         _v(_div),
    otherIncome:       _v(_other),
    sec80C:            _v(_c80c),
    sec80CCD1B:        _v(_c80ccd),
    sec80D:            _v(_c80d),
    sec80E:            _v(_c80e),
    sec80G:            _v(_c80g),
    homeLoanInterest:  _v(_hlInt),
    homeLoanPrincipal: _v(_hlPrin),
  );

  Future<void> _loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = <String, TextEditingController>{
        'tx_basic': _basic, 'tx_hra': _hra, 'tx_special': _special,
        'tx_lta': _lta, 'tx_otherAllow': _otherAllow, 'tx_rent': _rent,
        'tx_bizNet': _bizNet, 'tx_presump': _presump,
        'tx_stcgEq': _stcgEq, 'tx_ltcgEq': _ltcgEq,
        'tx_stcgOt': _stcgOt, 'tx_ltcgOt': _ltcgOt, 'tx_debtMF': _debtMF,
        'tx_fdInt': _fdInt, 'tx_savInt': _savInt, 'tx_div': _div,
        'tx_other': _other, 'tx_c80c': _c80c, 'tx_c80ccd': _c80ccd,
        'tx_c80d': _c80d, 'tx_c80e': _c80e, 'tx_c80g': _c80g,
        'tx_hlInt': _hlInt, 'tx_hlPrin': _hlPrin,
      };
      bool any = false;
      for (final e in data.entries) {
        final v = p.getString(e.key) ?? '';
        if (v.isNotEmpty) { e.value.text = v; any = true; }
      }
      setState(() {
        _metro        = p.getBool('tx_metro') ?? false;
        _isProfessional = p.getBool('tx_prof') ?? true;
      });
      if (any) _calculate();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = <String, TextEditingController>{
        'tx_basic': _basic, 'tx_hra': _hra, 'tx_special': _special,
        'tx_lta': _lta, 'tx_otherAllow': _otherAllow, 'tx_rent': _rent,
        'tx_bizNet': _bizNet, 'tx_presump': _presump,
        'tx_stcgEq': _stcgEq, 'tx_ltcgEq': _ltcgEq,
        'tx_stcgOt': _stcgOt, 'tx_ltcgOt': _ltcgOt, 'tx_debtMF': _debtMF,
        'tx_fdInt': _fdInt, 'tx_savInt': _savInt, 'tx_div': _div,
        'tx_other': _other, 'tx_c80c': _c80c, 'tx_c80ccd': _c80ccd,
        'tx_c80d': _c80d, 'tx_c80e': _c80e, 'tx_c80g': _c80g,
        'tx_hlInt': _hlInt, 'tx_hlPrin': _hlPrin,
      };
      for (final e in data.entries) { await p.setString(e.key, e.value.text); }
      await p.setBool('tx_metro', _metro);
      await p.setBool('tx_prof',  _isProfessional);
    } catch (_) {}
  }

  void _calculate() {
    HapticFeedback.lightImpact();
    final input = _buildInput();
    final result = TaxCalculatorService.calculate(input);
    _save();
    setState(() { _result = result; _showResult = true; });
    // Scroll to results handled by ListView key
  }

  void _clear() {
    for (final c in [_basic,_hra,_special,_lta,_otherAllow,_rent,
        _bizNet,_presump,_stcgEq,_ltcgEq,_stcgOt,_ltcgOt,_debtMF,
        _fdInt,_savInt,_div,_other,_c80c,_c80ccd,_c80d,_c80e,
        _c80g,_hlInt,_hlPrin]) { c.clear(); }
    setState(() { _metro = false; _isProfessional = true; _showResult = false; _result = null; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // FY banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Text('🇮🇳', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Income Tax Calculator',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('FY 2025-26 · AY 2026-27',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
            TextButton(
              onPressed: _clear,
              style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              child: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── SALARY ────────────────────────────────────────────────────────
        _section(
          key: 'salary', title: '💼 Salary Income',
          subtitle: 'Annual CTC breakdown', isDark: isDark, cardBg: cardBg,
          children: [
            _row([
              _field(_basic,   'Basic Salary / Year',    isDark),
              _field(_hra,     'HRA Received / Year',    isDark),
            ]),
            _row([
              _field(_special, 'Special Allowance',      isDark),
              _field(_lta,     'LTA / Year',             isDark),
            ]),
            _field(_otherAllow, 'Other Allowances',      isDark, full: true),
            _note('💡 Enter annual figures. Standard deduction of ₹75,000 (New) / ₹50,000 (Old) applied automatically.'),
          ],
        ),

        // ── HRA ───────────────────────────────────────────────────────────
        _section(
          key: 'hra', title: '🏠 House Rent (HRA)',
          subtitle: 'For Old Regime HRA exemption', isDark: isDark, cardBg: cardBg,
          children: [
            _field(_rent, 'Rent Paid / Year', isDark, full: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Metro City (Mumbai/Delhi/Chennai/Kolkata)',
                  style: TextStyle(fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text(
                  _metro ? '50% of Basic for HRA calc' : '40% of Basic for HRA calc',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              value: _metro,
              activeColor: const Color(0xFF667eea),
              onChanged: (v) => setState(() => _metro = v),
            ),
            _note('💡 HRA exemption = Min(HRA received, 50%/40% of basic, Rent paid − 10% of basic)'),
          ],
        ),

        // ── BUSINESS ─────────────────────────────────────────────────────
        _section(
          key: 'business', title: '🏢 Business / Freelance',
          subtitle: 'Net profit or presumptive', isDark: isDark, cardBg: cardBg,
          children: [
            _field(_bizNet,  'Net Business Profit (actual)',    isDark, full: true),
            const SizedBox(height: 8),
            const Divider(),
            const Text('OR — Presumptive Taxation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _field(_presump, 'Gross Receipts (44ADA/44AD)',    isDark, full: true),
            Row(children: [
              Expanded(child: _chip('Professional (44ADA)\n50% taxable',
                  _isProfessional, () => setState(() => _isProfessional = true))),
              const SizedBox(width: 10),
              Expanded(child: _chip('Business (44AD)\n8% taxable',
                  !_isProfessional, () => setState(() => _isProfessional = false))),
            ]),
            _note('💡 44ADA: Doctors, CAs, Lawyers, Consultants. 44AD: Traders, small businesses.'),
          ],
        ),

        // ── CAPITAL GAINS ─────────────────────────────────────────────────
        _section(
          key: 'capgains', title: '📈 Capital Gains',
          subtitle: 'Stocks, Mutual Funds', isDark: isDark, cardBg: cardBg,
          children: [
            _row([
              _field(_stcgEq, 'STCG Equity (20%)', isDark),
              _field(_ltcgEq, 'LTCG Equity (12.5%\nabove ₹1.25L)', isDark),
            ]),
            _row([
              _field(_stcgOt, 'STCG Other (slab)', isDark),
              _field(_ltcgOt, 'LTCG Other (12.5%)', isDark),
            ]),
            _field(_debtMF,  'Debt MF Gains (slab)', isDark, full: true),
            _note('💡 LTCG Equity: ₹1.25L exempt per year. STCG taxed at 20% (Budget 2024 change).'),
          ],
        ),

        // ── OTHER INCOME ──────────────────────────────────────────────────
        _section(
          key: 'other', title: '💰 Other Income',
          subtitle: 'FD, dividends, gifts', isDark: isDark, cardBg: cardBg,
          children: [
            _row([
              _field(_fdInt, 'FD Interest / Year', isDark),
              _field(_savInt,'Savings A/C Interest', isDark),
            ]),
            _row([
              _field(_div,   'Dividends', isDark),
              _field(_other, 'Other Income', isDark),
            ]),
            _note('💡 Savings interest up to ₹10,000 exempt under 80TTA (Old Regime).'),
          ],
        ),

        // ── OLD REGIME DEDUCTIONS ─────────────────────────────────────────
        _section(
          key: 'deductions', title: '🧾 Deductions (Old Regime)',
          subtitle: 'Section 80C, 80D, Home Loan etc.', isDark: isDark, cardBg: cardBg,
          children: [
            _row([
              _field(_c80c,  '80C — PPF/ELSS/EPF\n(max ₹1.5L)', isDark),
              _field(_c80ccd,'80CCD(1B) NPS\n(max ₹50K)', isDark),
            ]),
            _row([
              _field(_c80d,  '80D — Health Ins.\n(max ₹25K–50K)', isDark),
              _field(_c80e,  '80E — Education\nLoan Interest', isDark),
            ]),
            _row([
              _field(_c80g,  '80G — Donations', isDark),
              _field(_hlPrin,'Home Loan Principal\n(part of 80C)', isDark),
            ]),
            _field(_hlInt,   'Home Loan Interest — Sec 24b (max ₹2L)', isDark, full: true),
            _note('💡 80C max ₹1.5L includes EPF, PPF, ELSS, LIC, home loan principal, tuition fees.'),
          ],
        ),

        const SizedBox(height: 8),

        // ── CALCULATE BUTTON ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_rounded, size: 20),
            label: const Text('Calculate Tax',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── RESULTS ───────────────────────────────────────────────────────
        if (_showResult && _result != null) ...[
          _Results(result: _result!, isDark: isDark, cardBg: cardBg),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Section builder ───────────────────────────────────────────────────────
  Widget _section({
    required String key, required String title, required String subtitle,
    required bool isDark, required Color cardBg,
    required List<Widget> children,
  }) {
    final expanded = _expanded[key] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded[key] = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
                ],
              )),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, color: Colors.grey),
              ),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Divider(height: 1), const SizedBox(height: 12),
                  ...children]),
          ),
      ]),
    );
  }

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: children[0]),
      const SizedBox(width: 10),
      Expanded(child: children[1]),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label, bool isDark,
      {bool full = false}) {
    final w = TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(
          RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        prefixStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        labelStyle: const TextStyle(fontSize: 12),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (_) {},
    );
    if (full) return Padding(padding: const EdgeInsets.only(bottom: 12), child: w);
    return w;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF667eea).withOpacity(0.15)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF667eea) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF667eea) : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text,
        style: TextStyle(fontSize: 10, color: Colors.grey[500],
            fontStyle: FontStyle.italic)),
  );
}

// ════════════════════════════════════════════════════════════════════════
// RESULTS WIDGET
// ════════════════════════════════════════════════════════════════════════
class _Results extends StatefulWidget {
  final TaxResult result;
  final bool isDark;
  final Color cardBg;
  const _Results({required this.result, required this.isDark, required this.cardBg});
  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  String _viewing = ''; // 'new' | 'old' | ''

  @override
  void initState() {
    super.initState();
    _viewing = widget.result.recommendation;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final recommended = r.recommendation == 'new' ? r.newRegime : r.oldRegime;
    final other       = r.recommendation == 'new' ? r.oldRegime : r.newRegime;
    final recColor    = r.recommendation == 'new'
        ? const Color(0xFF667eea) : Colors.green;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Recommendation banner ───────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [recColor.withOpacity(0.85), recColor],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: recColor.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.recommendation == 'new' ? 'New' : 'Old'} Regime Recommended',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Save ${_f(r.savings)} per year',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ],
            )),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(r.reason,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // ── Side-by-side compare ────────────────────────────────────────────
      Row(children: [
        Expanded(child: _regimeCard(r.newRegime,
            isRec: r.recommendation == 'new',
            isViewing: _viewing == 'new',
            onTap: () => setState(() =>
                _viewing = _viewing == 'new' ? '' : 'new'))),
        const SizedBox(width: 10),
        Expanded(child: _regimeCard(r.oldRegime,
            isRec: r.recommendation == 'old',
            isViewing: _viewing == 'old',
            onTap: () => setState(() =>
                _viewing = _viewing == 'old' ? '' : 'old'))),
      ]),
      const SizedBox(height: 16),

      // ── Detail breakdown for selected regime ────────────────────────────
      if (_viewing.isNotEmpty)
        _Detail(
          breakdown: _viewing == 'new' ? r.newRegime : r.oldRegime,
          isDark: widget.isDark,
          cardBg: widget.cardBg,
        ),
      if (_viewing.isNotEmpty) const SizedBox(height: 16),

      // ── Monthly breakdown ───────────────────────────────────────────────
      _MonthlyCard(recommended, widget.isDark, widget.cardBg),
      const SizedBox(height: 16),
    ]);
  }

  Widget _regimeCard(TaxBreakdown bd, {
    required bool isRec,
    required bool isViewing,
    required VoidCallback onTap,
  }) {
    final color = bd.regime == 'New' ? const Color(0xFF667eea) : Colors.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isViewing ? color.withOpacity(0.1) : widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isViewing ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${bd.regime} Regime',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: color)),
            const Spacer(),
            if (isRec) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Best', style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(_f(bd.totalTax),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20)),
          Text('Total Tax', style: TextStyle(
              fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text(_pct(bd.effectiveRate),
              style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Effective Rate', style: TextStyle(
              fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 10),
          Text('Tap for details',
              style: TextStyle(fontSize: 10, color: color,
                  decoration: TextDecoration.underline)),
        ]),
      ),
    );
  }
}

// ── Detailed breakdown ────────────────────────────────────────────────────────
class _Detail extends StatelessWidget {
  final TaxBreakdown breakdown;
  final bool isDark;
  final Color cardBg;
  const _Detail({required this.breakdown, required this.isDark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final bd = breakdown;
    final color = bd.regime == 'New' ? const Color(0xFF667eea) : Colors.green;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${bd.regime} Regime — Full Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 16),

        // Income sources
        _subHead('Income Sources', isDark),
        ...bd.incomeBreakdown.entries.map((e) =>
            _row2(e.key, _f(e.value), isDark)),
        _divRow('Gross Total Income', _f(bd.grossIncome), bold: true, isDark: isDark),

        const SizedBox(height: 12),
        // Deductions
        if (bd.deductionBreakdown.isNotEmpty) ...[
          _subHead('Deductions', isDark),
          ...bd.deductionBreakdown.entries.map((e) =>
              _row2(e.key, '− ${_f(e.value)}', isDark, color: Colors.green)),
          _divRow('Total Deductions', '− ${_f(bd.totalDeductions)}',
              bold: true, color: Colors.green, isDark: isDark),
        ],

        const SizedBox(height: 12),
        _divRow('Taxable Income', _f(bd.taxableIncome),
            bold: true, isDark: isDark),

        const SizedBox(height: 12),
        // Slab calculation
        _subHead('Tax Calculation (Slab-wise)', isDark),
        ...bd.slabs.where((s) => s.taxable > 0).map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(s.label,
                style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87))),
            Text('${(s.rate * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: Text(_f(s.tax),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w500))),
          ]),
        )),

        const SizedBox(height: 8),
        _divRow('Basic Tax', _f(bd.basicTax), bold: true, isDark: isDark),
        if (bd.rebate87A > 0)
          _row2('Rebate u/s 87A', '− ${_f(bd.rebate87A)}', isDark,
              color: Colors.green),
        if (bd.surcharge > 0)
          _row2('Surcharge', _f(bd.surcharge), isDark),
        _row2('Health & Education Cess (4%)', _f(bd.cess), isDark),

        const Divider(height: 24),
        _divRow('Total Tax Payable', _f(bd.totalTax),
            bold: true, isDark: isDark,
            valueColor: color, valueFontSize: 18),
        _divRow('Effective Rate', _pct(bd.effectiveRate),
            bold: false, isDark: isDark, valueColor: color),
        _divRow('Take-Home (Annual)', _f(bd.takeHome),
            bold: true, isDark: isDark, valueColor: Colors.green),
      ]),
    );
  }

  Widget _subHead(String t, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12,
        color: isDark ? Colors.white54 : Colors.grey[500])),
  );

  Widget _row2(String k, String v, bool isDark,
      {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87))),
          Text(v, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: color ?? (isDark ? Colors.white : Colors.black87))),
        ]),
      );

  Widget _divRow(String k, String v, {
    required bool bold, required bool isDark,
    Color? color, Color? valueColor, double? valueFontSize,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(k, style: TextStyle(
          fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white : Colors.black87))),
      Text(v, style: TextStyle(
          fontSize: valueFontSize ?? 13,
          fontWeight: FontWeight.bold,
          color: valueColor ?? (isDark ? Colors.white : Colors.black))),
    ]),
  );
}

// ── Monthly card ──────────────────────────────────────────────────────────────
class _MonthlyCard extends StatelessWidget {
  final TaxBreakdown bd;
  final bool  isDark;
  final Color cardBg;
  const _MonthlyCard(this.bd, this.isDark, this.cardBg);

  @override
  Widget build(BuildContext context) {
    final monthly   = bd.grossIncome / 12;
    final monthlyTax = bd.totalTax / 12;
    final takehome  = monthly - monthlyTax;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Monthly Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: isDark ? Colors.white : Colors.black87)),
        Text('Based on ${bd.regime} Regime',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),
        Row(children: [
          _cell('Gross Income', monthly, Colors.blue),
          _cell('TDS / Month', monthlyTax, Colors.red),
          _cell('Take-Home', takehome, Colors.green),
        ]),
      ]),
    );
  }

  Widget _cell(String label, double val, Color color) => Expanded(child: Column(
    children: [
      Text(_f(val), style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
    ],
  ));
}