// lib/screens/calendar_screen.dart
// Financial Calendar — transactions, EMI dates, goals, recurring events
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../models/loan_model.dart';
import '../models/recurring_transaction_model.dart';
import '../services/transaction_service.dart';
import '../services/goal_service.dart';
import '../services/loan_service.dart';
import '../services/recurring_transaction_service.dart';
import 'transaction_detail_screen.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _inr.format(v);

// ── Event types ───────────────────────────────────────────────────────────────
enum CalEventType { income, expense, emi, goal, recurring }

extension CalEventTypeX on CalEventType {
  Color get color => switch (this) {
    CalEventType.income    => const Color(0xFF43e97b),
    CalEventType.expense   => const Color(0xFFfa709a),
    CalEventType.emi       => const Color(0xFF667eea),
    CalEventType.goal      => const Color(0xFFf9ca24),
    CalEventType.recurring => const Color(0xFFfd9644),
  };
  String get label => switch (this) {
    CalEventType.income    => 'Income',
    CalEventType.expense   => 'Expense',
    CalEventType.emi       => 'EMI Due',
    CalEventType.goal      => 'Goal Deadline',
    CalEventType.recurring => 'Recurring',
  };
  String get emoji => switch (this) {
    CalEventType.income    => '💚',
    CalEventType.expense   => '🔴',
    CalEventType.emi       => '🏦',
    CalEventType.goal      => '🎯',
    CalEventType.recurring => '🔄',
  };
}

// ── Calendar event model ──────────────────────────────────────────────────────
class CalEvent {
  final CalEventType type;
  final String       title;
  final String       subtitle;
  final double       amount;
  final DateTime     date;
  final String?      id;

  const CalEvent({
    required this.type,    required this.title,
    required this.subtitle,required this.amount,
    required this.date,    this.id,
  });
}

// ════════════════════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Services
  final _txnSvc  = TransactionService();
  final _goalSvc = GoalService();
  final _loanSvc = LoanService();
  final _recSvc  = RecurringTransactionService();

  // Calendar state
  CalendarFormat _fmt      = CalendarFormat.month;
  DateTime       _focused  = DateTime.now();
  DateTime       _selected = DateTime.now();

  // All events keyed by normalised date
  Map<DateTime, List<CalEvent>> _events = {};
  bool _loading = true;

  // Active filter
  final Set<CalEventType> _activeFilters = {
    CalEventType.income, CalEventType.expense,
    CalEventType.emi,    CalEventType.goal,
    CalEventType.recurring,
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  void _addEvent(Map<DateTime, List<CalEvent>> map, CalEvent e) {
    final k = _norm(e.date);
    map.putIfAbsent(k, () => []).add(e);
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final map = <DateTime, List<CalEvent>>{};

    // 1. Transactions
    final txns = await _txnSvc.getTransactionsList();
    for (final t in txns) {
      final type = t.type == 'income'
          ? CalEventType.income : CalEventType.expense;
      _addEvent(map, CalEvent(
        type:     type,
        title:    t.category,
        subtitle: t.note ?? t.type,
        amount:   t.amount,
        date:     t.date,
        id:       t.id,
      ));
    }

    // 2. Loan EMI dates (generate next 12 months of EMI due dates)
    try {
      final loans = await _loanSvc.getActiveLoans().first;
      final now   = DateTime.now();
      for (final loan in loans) {
        // EMI day = same day of month as startDate
        final emiDay = loan.startDate.day;
        for (int m = 0; m < 13; m++) {
          final dueDate = DateTime(now.year, now.month + m, emiDay);
          if (dueDate.isAfter(loan.expectedEndDate)) break;
          _addEvent(map, CalEvent(
            type:     CalEventType.emi,
            title:    '${loan.type.emoji} ${loan.name}',
            subtitle: 'EMI due · ${loan.lenderName ?? loan.type.label}',
            amount:   loan.emi,
            date:     dueDate,
            id:       loan.id,
          ));
        }
      }
    } catch (_) {}

    // 3. Goal deadlines
    try {
      final goalSnap = await _goalSvc.getGoals().first;
      for (final doc in goalSnap.docs) {
        final g = GoalModel.fromFirestore(doc);
        if (!g.isCompleted) {
          _addEvent(map, CalEvent(
            type:     CalEventType.goal,
            title:    '${g.icon ?? '🎯'} ${g.name}',
            subtitle: 'Goal deadline · ${_f(g.targetAmount)} target',
            amount:   g.targetAmount,
            date:     g.targetDate,
            id:       g.id,
          ));
        }
      }
    } catch (_) {}

    // 4. Recurring transactions (next 3 occurrences each)
    try {
      final recList = await _recSvc.getRecurringTransactions().first;
      for (final r in recList) {
        if (!r.isActive) continue;
        DateTime next = r.nextDate;
        for (int i = 0; i < 3; i++) {
          final type = r.type == 'income'
              ? CalEventType.recurring : CalEventType.recurring;
          _addEvent(map, CalEvent(
            type:     type,
            title:    '🔄 ${r.category}',
            subtitle: 'Recurring ${r.type} · ${r.frequency}',
            amount:   r.amount,
            date:     next,
            id:       r.id,
          ));
          next = _nextOccurrence(next, r.frequency);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() { _events = map; _loading = false; });
    }
  }

  DateTime _nextOccurrence(DateTime from, String freq) => switch (freq) {
    'daily'   => from.add(const Duration(days: 1)),
    'weekly'  => from.add(const Duration(days: 7)),
    'yearly'  => DateTime(from.year + 1, from.month, from.day),
    _         => DateTime(from.year, from.month + 1, from.day), // monthly
  };

  List<CalEvent> _eventsForDay(DateTime day) {
    final all = _events[_norm(day)] ?? [];
    return all.where((e) => _activeFilters.contains(e.type)).toList();
  }

  // ── Month summary totals ───────────────────────────────────────────────────
  _MonthSummary _monthlySummary(DateTime month) {
    double income = 0, expense = 0, emi = 0;
    _events.forEach((date, events) {
      if (date.year == month.year && date.month == month.month) {
        for (final e in events) {
          if (e.type == CalEventType.income)   income  += e.amount;
          if (e.type == CalEventType.expense)  expense += e.amount;
          if (e.type == CalEventType.emi)      emi     += e.amount;
        }
      }
    });
    return _MonthSummary(income: income, expense: expense, emi: emi);
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F8);
    final cardBg  = isDark ? const Color(0xFF1E2530) : Colors.white;
    final summary = _monthlySummary(_focused);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Financial Calendar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E2530) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Go to today',
            onPressed: () => setState(() {
              _focused  = DateTime.now();
              _selected = DateTime.now();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Month summary banner ──────────────────────────────────────
              _MonthlySummaryBar(
                  summary: summary, isDark: isDark, month: _focused),

              // ── Filter chips ──────────────────────────────────────────────
              _FilterBar(
                active:   _activeFilters,
                onToggle: (t) => setState(() {
                  if (_activeFilters.contains(t)) {
                    if (_activeFilters.length > 1) _activeFilters.remove(t);
                  } else {
                    _activeFilters.add(t);
                  }
                }),
                isDark: isDark,
              ),

              // ── Calendar ──────────────────────────────────────────────────
              Container(
                color: cardBg,
                child: TableCalendar<CalEvent>(
                  firstDay:  DateTime(2020),
                  lastDay:   DateTime(2030, 12, 31),
                  focusedDay: _focused,
                  calendarFormat: _fmt,
                  selectedDayPredicate: (d) => isSameDay(_selected, d),
                  eventLoader: _eventsForDay,
                  onDaySelected: (sel, foc) => setState(() {
                    _selected = sel; _focused = foc;
                  }),
                  onFormatChanged: (f) => setState(() => _fmt = f),
                  onPageChanged:   (f) => setState(() => _focused = f),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFF667eea),
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(
                        color: isDark ? Colors.red[200] : Colors.red[400]),
                    defaultTextStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    outsideTextStyle:
                        const TextStyle(color: Colors.grey),
                    todayTextStyle: const TextStyle(
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.bold),
                    selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    markerSize: 5,
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: true,
                    titleTextStyle: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87),
                    formatButtonDecoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: const TextStyle(
                        color: Color(0xFF667eea), fontSize: 12),
                    leftChevronIcon: Icon(Icons.chevron_left,
                        color: isDark ? Colors.white : Colors.black54),
                    rightChevronIcon: Icon(Icons.chevron_right,
                        color: isDark ? Colors.white : Colors.black54),
                    decoration: BoxDecoration(color: cardBg),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45),
                    weekendStyle: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.red[200] : Colors.red[300]),
                  ),
                  // Custom marker builder — colour dots per event type
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (ctx, date, events) {
                      if (events.isEmpty) return null;
                      // Collect unique types
                      final types = events
                          .map((e) => e.type)
                          .toSet()
                          .take(4)
                          .toList();
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: types.map((t) => Container(
                            width: 5, height: 5,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 0.8),
                            decoration: BoxDecoration(
                              color: t.color,
                              shape: BoxShape.circle,
                            ),
                          )).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Divider(height: 1),

              // ── Selected day events list ───────────────────────────────────
              Expanded(child: _DayEventsList(
                date:   _selected,
                events: _eventsForDay(_selected),
                isDark: isDark,
                cardBg: cardBg,
              )),
            ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Monthly summary banner
// ════════════════════════════════════════════════════════════════════════════
class _MonthSummary {
  final double income, expense, emi;
  const _MonthSummary(
      {required this.income,
       required this.expense,
       required this.emi});
}

class _MonthlySummaryBar extends StatelessWidget {
  final _MonthSummary summary;
  final bool isDark;
  final DateTime month;
  const _MonthlySummaryBar(
      {required this.summary,
       required this.isDark,
       required this.month});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(children: [
        _chip('💚 In', summary.income,
            const Color(0xFF43e97b)),
        const SizedBox(width: 10),
        _chip('🔴 Out', summary.expense,
            const Color(0xFFfa709a)),
        const SizedBox(width: 10),
        _chip('🏦 EMI', summary.emi,
            const Color(0xFF667eea)),
        const Spacer(),
        Text(DateFormat('MMMM y').format(month),
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38)),
      ]),
    );
  }

  Widget _chip(String label, double val, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color,
                  fontWeight: FontWeight.bold)),
          Text(_f(val),
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Filter chips bar
// ════════════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final Set<CalEventType> active;
  final void Function(CalEventType) onToggle;
  final bool isDark;
  const _FilterBar(
      {required this.active,
       required this.onToggle,
       required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2530) : Colors.white;
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: CalEventType.values.map((t) {
            final sel = active.contains(t);
            return GestureDetector(
              onTap: () => onToggle(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
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
                child: Text(
                  '${t.emoji} ${t.label}',
                  style: TextStyle(
                      fontSize: 11,
                      color: sel ? t.color : Colors.grey,
                      fontWeight: sel
                          ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Day events list
// ════════════════════════════════════════════════════════════════════════════
class _DayEventsList extends StatelessWidget {
  final DateTime      date;
  final List<CalEvent> events;
  final bool          isDark;
  final Color         cardBg;

  const _DayEventsList({
    required this.date,    required this.events,
    required this.isDark,  required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(date, DateTime.now());
    final label   = isToday
        ? 'Today · ${DateFormat('d MMMM').format(date)}'
        : DateFormat('EEEE, d MMMM y').format(date);

    if (events.isEmpty) {
      return Column(children: [
        _dayHeader(label),
        const Expanded(child: _EmptyDay()),
      ]);
    }

    // Group by type
    final grouped = <CalEventType, List<CalEvent>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.type, () => []).add(e);
    }

    // Day totals
    final income  = events
        .where((e) => e.type == CalEventType.income)
        .fold(0.0, (s, e) => s + e.amount);
    final expense = events
        .where((e) => e.type == CalEventType.expense)
        .fold(0.0, (s, e) => s + e.amount);

    return Column(children: [
      _dayHeader(label, income: income, expense: expense),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: CalEventType.values
              .where((t) => grouped.containsKey(t))
              .expand((t) => [
                // Section header
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 6, top: 8),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: t.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: t.color)),
                  ]),
                ),
                // Event tiles
                ...grouped[t]!.map((e) => _EventTile(
                  event: e, isDark: isDark,
                  cardBg: cardBg,
                  onTap: () => _onTap(context, e),
                )),
              ])
              .toList(),
        ),
      ),
    ]);
  }

  Widget _dayHeader(String label,
      {double income = 0, double expense = 0}) =>
      Container(
        color: cardBg,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13))),
          if (income > 0) ...[
            Text('+${_f(income)}',
                style: const TextStyle(
                    color: Color(0xFF43e97b),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(width: 10),
          ],
          if (expense > 0)
            Text('-${_f(expense)}',
                style: const TextStyle(
                    color: Color(0xFFfa709a),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
        ]),
      );

  void _onTap(BuildContext ctx, CalEvent e) {
    if (e.type == CalEventType.income ||
        e.type == CalEventType.expense) {
      if (e.id != null) {
        // Navigate to transaction detail
        // (would need full TransactionModel — show snackbar instead)
      }
    }
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(
          '${e.type.emoji} ${e.title}  ·  ${_f(e.amount)}'),
      backgroundColor: e.type.color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ── Event tile ────────────────────────────────────────────────────────────────
class _EventTile extends StatelessWidget {
  final CalEvent     event;
  final bool         isDark;
  final Color        cardBg;
  final VoidCallback onTap;

  const _EventTile({
    required this.event,  required this.isDark,
    required this.cardBg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = event.type.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 3)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(event.type.emoji,
                style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              Text(event.subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          Text(
            '${event.type == CalEventType.expense ? '-' : ''}${_f(event.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, color: color),
          ),
        ]),
      ),
    );
  }
}

// ── Empty day ─────────────────────────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      const Text('📅', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      const Text('No events this day',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 6),
      Text('Select another day or add a transaction',
          style: TextStyle(color: Colors.grey[500],
              fontSize: 12)),
    ]),
  );
}