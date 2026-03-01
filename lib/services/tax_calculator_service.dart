// lib/services/tax_calculator_service.dart
// Indian Income Tax Calculator FY 2025-26 (AY 2026-27)
// Supports: New Regime + Old Regime, all income heads, HRA, deductions

class TaxInput {
  // ── Salary ───────────────────────────────────────────────────────────────
  final double basicSalary;         // per year
  final double hra;                 // HRA received per year
  final double specialAllowance;
  final double lta;                 // Leave Travel Allowance
  final double otherAllowances;
  final double epfEmployee;         // 12% of basic (auto or manual)

  // ── House Rent ───────────────────────────────────────────────────────────
  final double rentPaid;            // per year
  final bool   metroCity;           // Mumbai/Delhi/Chennai/Kolkata

  // ── Business / Freelance ─────────────────────────────────────────────────
  final double businessIncome;      // net profit after expenses
  final double presumptiveIncome;   // 44ADA / 44AD gross (auto 50% deduction)
  final bool   isProfessional;      // 44ADA (50%) vs 44AD (6%/8%)

  // ── Capital Gains ─────────────────────────────────────────────────────────
  final double stcgEquity;          // Short term equity (15%)
  final double ltcgEquity;          // Long term equity >1L (10%)
  final double stcgOther;           // Other STCG (slab rate)
  final double ltcgOther;           // Other LTCG (20% with indexation)
  final double debtFundGains;       // Debt MF (slab rate from Apr 2023)

  // ── Other Income ─────────────────────────────────────────────────────────
  final double fdInterest;
  final double savingsInterest;
  final double dividends;
  final double otherIncome;

  // ── Old Regime Deductions ─────────────────────────────────────────────────
  final double sec80C;              // max 1,50,000
  final double sec80CCD1B;          // NPS extra 50,000
  final double sec80D;              // Health insurance max 25,000/50,000
  final double sec80E;              // Education loan interest (no limit)
  final double sec80G;              // Donations (50%/100%)
  final double sec80TTA;            // Savings interest max 10,000
  final double homeLoanInterest;    // Sec 24b max 2,00,000
  final double homeLoanPrincipal;   // Part of 80C

  const TaxInput({
    this.basicSalary       = 0,
    this.hra               = 0,
    this.specialAllowance  = 0,
    this.lta               = 0,
    this.otherAllowances   = 0,
    this.epfEmployee       = 0,
    this.rentPaid          = 0,
    this.metroCity         = false,
    this.businessIncome    = 0,
    this.presumptiveIncome = 0,
    this.isProfessional    = true,
    this.stcgEquity        = 0,
    this.ltcgEquity        = 0,
    this.stcgOther         = 0,
    this.ltcgOther         = 0,
    this.debtFundGains     = 0,
    this.fdInterest        = 0,
    this.savingsInterest   = 0,
    this.dividends         = 0,
    this.otherIncome       = 0,
    this.sec80C            = 0,
    this.sec80CCD1B        = 0,
    this.sec80D            = 0,
    this.sec80E            = 0,
    this.sec80G            = 0,
    this.sec80TTA          = 0,
    this.homeLoanInterest  = 0,
    this.homeLoanPrincipal = 0,
  });

  TaxInput copyWith({
    double? basicSalary, double? hra, double? specialAllowance,
    double? lta, double? otherAllowances, double? epfEmployee,
    double? rentPaid, bool? metroCity,
    double? businessIncome, double? presumptiveIncome, bool? isProfessional,
    double? stcgEquity, double? ltcgEquity,
    double? stcgOther, double? ltcgOther, double? debtFundGains,
    double? fdInterest, double? savingsInterest,
    double? dividends, double? otherIncome,
    double? sec80C, double? sec80CCD1B, double? sec80D,
    double? sec80E, double? sec80G, double? sec80TTA,
    double? homeLoanInterest, double? homeLoanPrincipal,
  }) => TaxInput(
    basicSalary:       basicSalary       ?? this.basicSalary,
    hra:               hra               ?? this.hra,
    specialAllowance:  specialAllowance  ?? this.specialAllowance,
    lta:               lta               ?? this.lta,
    otherAllowances:   otherAllowances   ?? this.otherAllowances,
    epfEmployee:       epfEmployee       ?? this.epfEmployee,
    rentPaid:          rentPaid          ?? this.rentPaid,
    metroCity:         metroCity         ?? this.metroCity,
    businessIncome:    businessIncome    ?? this.businessIncome,
    presumptiveIncome: presumptiveIncome ?? this.presumptiveIncome,
    isProfessional:    isProfessional    ?? this.isProfessional,
    stcgEquity:        stcgEquity        ?? this.stcgEquity,
    ltcgEquity:        ltcgEquity        ?? this.ltcgEquity,
    stcgOther:         stcgOther         ?? this.stcgOther,
    ltcgOther:         ltcgOther         ?? this.ltcgOther,
    debtFundGains:     debtFundGains     ?? this.debtFundGains,
    fdInterest:        fdInterest        ?? this.fdInterest,
    savingsInterest:   savingsInterest   ?? this.savingsInterest,
    dividends:         dividends         ?? this.dividends,
    otherIncome:       otherIncome       ?? this.otherIncome,
    sec80C:            sec80C            ?? this.sec80C,
    sec80CCD1B:        sec80CCD1B        ?? this.sec80CCD1B,
    sec80D:            sec80D            ?? this.sec80D,
    sec80E:            sec80E            ?? this.sec80E,
    sec80G:            sec80G            ?? this.sec80G,
    sec80TTA:          sec80TTA          ?? this.sec80TTA,
    homeLoanInterest:  homeLoanInterest  ?? this.homeLoanInterest,
    homeLoanPrincipal: homeLoanPrincipal ?? this.homeLoanPrincipal,
  );
}

// ── Output ────────────────────────────────────────────────────────────────────

class TaxSlabDetail {
  final String label;   // "Up to ₹3L"
  final double from;
  final double to;      // 0 = no upper limit
  final double rate;    // 0.05 = 5%
  final double taxable; // amount in this slab
  final double tax;

  const TaxSlabDetail({
    required this.label,   required this.from,
    required this.to,      required this.rate,
    required this.taxable, required this.tax,
  });
}

class TaxBreakdown {
  final String   regime;           // 'New' or 'Old'
  final double   grossIncome;
  final double   totalDeductions;
  final double   taxableIncome;
  final double   basicTax;         // before rebate/cess
  final double   rebate87A;
  final double   surcharge;
  final double   cess;             // 4% health & education
  final double   totalTax;         // final payable
  final double   effectiveRate;    // %
  final double   takeHome;         // grossIncome - totalTax
  final List<TaxSlabDetail> slabs;
  final Map<String, double> deductionBreakdown;
  final Map<String, double> incomeBreakdown;

  const TaxBreakdown({
    required this.regime,           required this.grossIncome,
    required this.totalDeductions,  required this.taxableIncome,
    required this.basicTax,         required this.rebate87A,
    required this.surcharge,        required this.cess,
    required this.totalTax,         required this.effectiveRate,
    required this.takeHome,         required this.slabs,
    required this.deductionBreakdown,
    required this.incomeBreakdown,
  });
}

class TaxResult {
  final TaxBreakdown newRegime;
  final TaxBreakdown oldRegime;
  final String       recommendation; // 'new' | 'old'
  final double       savings;        // how much better recommended regime is
  final String       reason;

  const TaxResult({
    required this.newRegime,
    required this.oldRegime,
    required this.recommendation,
    required this.savings,
    required this.reason,
  });
}

// ── Calculator ────────────────────────────────────────────────────────────────

class TaxCalculatorService {

  static TaxResult calculate(TaxInput inp) {
    final newR = _calculateNew(inp);
    final oldR = _calculateOld(inp);

    final better  = newR.totalTax <= oldR.totalTax ? 'new' : 'old';
    final savings = (newR.totalTax - oldR.totalTax).abs();
    final reason  = better == 'new'
        ? 'New Regime saves ₹${_fmt(savings)} — lower slab rates outweigh deductions'
        : 'Old Regime saves ₹${_fmt(savings)} — your deductions (₹${_fmt(oldR.totalDeductions)}) make it worth it';

    return TaxResult(
      newRegime:      newR,
      oldRegime:      oldR,
      recommendation: better,
      savings:        savings,
      reason:         reason,
    );
  }

  // ── NEW REGIME FY2025-26 ──────────────────────────────────────────────────
  // Slabs: 0-3L=0%, 3-7L=5%, 7-10L=10%, 10-12L=15%, 12-15L=20%, >15L=30%
  // Standard deduction: ₹75,000 for salaried
  // Rebate 87A: Full tax rebate if taxable income ≤ ₹7L (new) → tax = 0
  static TaxBreakdown _calculateNew(TaxInput inp) {
    final inc = _buildIncomeBreakdown(inp);
    final grossIncome = inc.values.fold(0.0, (s, v) => s + v);

    // New regime: only standard deduction + NPS employer (not user input)
    final hasSalary = inp.basicSalary > 0;
    final stdDeduction = hasSalary ? 75000.0 : 0.0;

    // Special income taxed separately (capital gains)
    final stcgEquityTax  = inp.stcgEquity * 0.20;   // 20% from Jul 2024 budget
    final ltcgEquityTax  = (inp.ltcgEquity - 125000.0).clamp(0.0, double.infinity).toDouble() * 0.125; // 12.5% above 1.25L
    final ltcgOtherTax   = inp.ltcgOther * 0.125;   // 12.5% no indexation new regime

    // Normal income (exclude special CG)
    final normalIncome = grossIncome
        - inp.stcgEquity - inp.ltcgEquity - inp.ltcgOther;
    final double taxableNormal = (normalIncome - stdDeduction).clamp(0.0, double.infinity).toDouble();

    final deductions = {'Standard Deduction': stdDeduction};
    final slabs = _newSlabs(taxableNormal);
    final normalTax = slabs.fold(0.0, (s, sl) => s + sl.tax);

    // Rebate 87A: if total normal taxable ≤ 12,00,000 (FY2025-26) full rebate
    final double rebate = taxableNormal <= 1200000 ? normalTax : 0.0;
    final double taxAfterRebate = (normalTax - rebate).clamp(0.0, double.infinity).toDouble();

    final specialTax   = stcgEquityTax + ltcgEquityTax + ltcgOtherTax;
    final basicTax     = taxAfterRebate + specialTax;
    final surcharge    = _surcharge(basicTax, grossIncome - stdDeduction);
    final taxWithSurcharge = basicTax + surcharge;
    final cess         = taxWithSurcharge * 0.04;
    final totalTax     = taxWithSurcharge + cess;
    final effRate      = grossIncome > 0 ? totalTax / grossIncome * 100 : 0.0;

    return TaxBreakdown(
      regime:              'New',
      grossIncome:         grossIncome,
      totalDeductions:     stdDeduction,
      taxableIncome:       taxableNormal,
      basicTax:            normalTax,
      rebate87A:           rebate,
      surcharge:           surcharge,
      cess:                cess,
      totalTax:            totalTax,
      effectiveRate:       effRate,
      takeHome:            grossIncome - totalTax,
      slabs:               slabs,
      deductionBreakdown:  deductions,
      incomeBreakdown:     inc,
    );
  }

  // ── OLD REGIME FY2025-26 ──────────────────────────────────────────────────
  // Slabs: 0-2.5L=0%, 2.5-5L=5%, 5-10L=20%, >10L=30%
  // Standard deduction: ₹50,000
  // Rebate 87A: if taxable ≤ ₹5L, tax rebate up to ₹12,500
  static TaxBreakdown _calculateOld(TaxInput inp) {
    final inc = _buildIncomeBreakdown(inp);
    final grossIncome = inc.values.fold(0.0, (s, v) => s + v);

    // HRA exemption
    final hraExempt = _hraExemption(inp);

    // Deductions
    final double sec80CTotal  = (inp.sec80C + inp.homeLoanPrincipal).clamp(0.0, 150000.0).toDouble();
    final double sec80DTotal  = inp.sec80D.clamp(0.0, 50000.0).toDouble();
    final double sec80TTAVal  = inp.savingsInterest.clamp(0.0, 10000.0).toDouble();
    final double homeLoanInt  = inp.homeLoanInterest.clamp(0.0, 200000.0).toDouble();
    final double stdDeduction = inp.basicSalary > 0 ? 50000.0 : 0.0;

    final deductionMap = <String, double>{};
    if (stdDeduction > 0)  deductionMap['Standard Deduction'] = stdDeduction;
    if (hraExempt   > 0)  deductionMap['HRA Exemption']       = hraExempt;
    if (sec80CTotal > 0)  deductionMap['80C (ELSS/PPF/EPF)']  = sec80CTotal;
    if (inp.sec80CCD1B>0) deductionMap['80CCD(1B) NPS']       = inp.sec80CCD1B.clamp(0.0, 50000.0).toDouble();
    if (sec80DTotal > 0)  deductionMap['80D Health Insurance'] = sec80DTotal;
    if (inp.sec80E  > 0)  deductionMap['80E Education Loan']   = inp.sec80E;
    if (inp.sec80G  > 0)  deductionMap['80G Donations']        = inp.sec80G;
    if (sec80TTAVal > 0)  deductionMap['80TTA Savings Int.']   = sec80TTAVal;
    if (homeLoanInt > 0)  deductionMap['Sec 24b Home Loan']    = homeLoanInt;

    final totalDeductions = deductionMap.values.fold(0.0, (s, v) => s + v);

    // Special income taxed separately
    final stcgEquityTax = inp.stcgEquity  * 0.20;
    final ltcgEquityTax = (inp.ltcgEquity - 100000.0).clamp(0.0, double.infinity).toDouble() * 0.10;
    final ltcgOtherTax  = inp.ltcgOther   * 0.20;  // with indexation benefit old regime

    final normalIncome  = grossIncome
        - inp.stcgEquity - inp.ltcgEquity - inp.ltcgOther;
    final double taxableNormal = (normalIncome - totalDeductions).clamp(0.0, double.infinity).toDouble();

    final slabs    = _oldSlabs(taxableNormal);
    final normalTax = slabs.fold(0.0, (s, sl) => s + sl.tax);

    // Rebate 87A old: max 12500 if taxable ≤ 5L
    final double rebate = taxableNormal <= 500000 ? normalTax.clamp(0.0, 12500.0).toDouble() : 0.0;
    final double taxAfterRebate = (normalTax - rebate).clamp(0.0, double.infinity).toDouble();

    final specialTax      = stcgEquityTax + ltcgEquityTax + ltcgOtherTax;
    final basicTax        = taxAfterRebate + specialTax;
    final surcharge       = _surcharge(basicTax, taxableNormal);
    final taxWithSurcharge = basicTax + surcharge;
    final cess            = taxWithSurcharge * 0.04;
    final totalTax        = taxWithSurcharge + cess;
    final effRate         = grossIncome > 0 ? totalTax / grossIncome * 100 : 0.0;

    return TaxBreakdown(
      regime:             'Old',
      grossIncome:        grossIncome,
      totalDeductions:    totalDeductions,
      taxableIncome:      taxableNormal,
      basicTax:           normalTax,
      rebate87A:          rebate,
      surcharge:          surcharge,
      cess:               cess,
      totalTax:           totalTax,
      effectiveRate:      effRate,
      takeHome:           grossIncome - totalTax,
      slabs:              slabs,
      deductionBreakdown: deductionMap,
      incomeBreakdown:    inc,
    );
  }

  // ── Income breakdown ──────────────────────────────────────────────────────
  static Map<String, double> _buildIncomeBreakdown(TaxInput inp) {
    final map = <String, double>{};

    // Gross salary
    final grossSalary = inp.basicSalary + inp.hra + inp.specialAllowance
        + inp.lta + inp.otherAllowances;
    if (grossSalary > 0) map['Salary (Gross)'] = grossSalary;

    // Presumptive business
    if (inp.presumptiveIncome > 0) {
      final presumptiveTaxable = inp.isProfessional
          ? inp.presumptiveIncome * 0.50   // 44ADA: 50% of gross
          : inp.presumptiveIncome * 0.08;  // 44AD: 8% of gross
      map['Business (Presumptive)'] = presumptiveTaxable;
    }
    if (inp.businessIncome > 0) map['Business / Freelance'] = inp.businessIncome;

    if (inp.stcgEquity > 0) map['STCG Equity']   = inp.stcgEquity;
    if (inp.ltcgEquity > 0) map['LTCG Equity']   = inp.ltcgEquity;
    if (inp.stcgOther  > 0) map['STCG Other']    = inp.stcgOther;
    if (inp.ltcgOther  > 0) map['LTCG Other']    = inp.ltcgOther;
    if (inp.debtFundGains>0) map['Debt Fund Gains']= inp.debtFundGains;
    if (inp.fdInterest  > 0) map['FD Interest']   = inp.fdInterest;
    if (inp.savingsInterest>0) map['Savings Interest'] = inp.savingsInterest;
    if (inp.dividends   > 0) map['Dividends']     = inp.dividends;
    if (inp.otherIncome > 0) map['Other Income']  = inp.otherIncome;

    return map;
  }

  // ── HRA exemption (old regime) ────────────────────────────────────────────
  static double _hraExemption(TaxInput inp) {
    if (inp.hra <= 0 || inp.rentPaid <= 0) return 0;
    final basic        = inp.basicSalary;
    final hraReceived  = inp.hra;
    final rent         = inp.rentPaid;
    final metroPercent = inp.metroCity ? 0.50 : 0.40;

    // Min of 3 rules
    final rule1 = hraReceived;
    final rule2 = basic * metroPercent;
    final rule3 = (rent - basic * 0.10).clamp(0.0, double.infinity).toDouble();

    return [rule1, rule2, rule3].reduce((a, b) => a < b ? a : b).toDouble();
  }

  // ── New Regime slabs ──────────────────────────────────────────────────────
  static List<TaxSlabDetail> _newSlabs(double income) {
    final ranges = [
      (0.0,      300000.0,  0.00, 'Up to ₹3L'),
      (300000.0, 700000.0,  0.05, '₹3L – ₹7L'),
      (700000.0, 1000000.0, 0.10, '₹7L – ₹10L'),
      (1000000.0,1200000.0, 0.15, '₹10L – ₹12L'),
      (1200000.0,1500000.0, 0.20, '₹12L – ₹15L'),
      (1500000.0,0.0,       0.30, 'Above ₹15L'),
    ];
    return _computeSlabs(income, ranges);
  }

  // ── Old Regime slabs ──────────────────────────────────────────────────────
  static List<TaxSlabDetail> _oldSlabs(double income) {
    final ranges = [
      (0.0,      250000.0,  0.00, 'Up to ₹2.5L'),
      (250000.0, 500000.0,  0.05, '₹2.5L – ₹5L'),
      (500000.0, 1000000.0, 0.20, '₹5L – ₹10L'),
      (1000000.0,0.0,       0.30, 'Above ₹10L'),
    ];
    return _computeSlabs(income, ranges);
  }

  static List<TaxSlabDetail> _computeSlabs(
      double income, List<(double, double, double, String)> ranges) {
    final result = <TaxSlabDetail>[];
    for (final (from, to, rate, label) in ranges) {
      if (income <= from) break;
      final upper   = to == 0 ? income : to;
      final double taxable = (income.clamp(from, upper).toDouble() - from).clamp(0.0, double.infinity).toDouble();
      result.add(TaxSlabDetail(
        label: label, from: from, to: to,
        rate: rate, taxable: taxable,
        tax: taxable * rate,
      ));
    }
    return result;
  }

  // ── Surcharge ─────────────────────────────────────────────────────────────
  static double _surcharge(double tax, double income) {
    if (income > 50000000) return tax * 0.25;
    if (income > 20000000) return tax * 0.15;
    if (income > 10000000) return tax * 0.15;
    if (income > 5000000)  return tax * 0.10;
    return 0;
  }

  static String _fmt(double v) =>
      v >= 10000000 ? '${(v / 10000000).toStringAsFixed(1)}Cr'
      : v >= 100000  ? '${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000    ? '${(v / 1000).toStringAsFixed(0)}K'
      : v.toStringAsFixed(0);
}