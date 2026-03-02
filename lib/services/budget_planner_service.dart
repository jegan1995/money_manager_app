// lib/services/budget_planner_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_planner_model.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class BudgetPlannerService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _txnSvc = TransactionService();

  String? get _uid => _auth.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('budget_plans');

  // ── Stream of all plans for current month ────────────────────────────────
  Stream<List<BudgetPlan>> getPlansForMonth(int month, int year) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId', isEqualTo: uid)
        .where('month',  isEqualTo: month)
        .where('year',   isEqualTo: year)
        .snapshots()
        .map((s) => s.docs.map(BudgetPlan.fromFirestore).toList());
  }

  // Stream all plans (for custom ranges)
  Stream<List<BudgetPlan>> getAllPlans() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BudgetPlan.fromFirestore).toList());
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<void> addPlan(BudgetPlan plan) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.add(plan.copyWith(userId: uid).toMap());
  }

  Future<void> updatePlan(BudgetPlan plan) async {
    if (plan.id == null) return;
    await _col.doc(plan.id).update(plan.toMap());
  }

  Future<void> deletePlan(String id) => _col.doc(id).delete();

  // ── Compute spending for a plan ───────────────────────────────────────────
  Future<BudgetStatus> getStatus(BudgetPlan plan) async {
    final txns = await _txnSvc.getTransactionsList();
    return _computeStatus(plan, txns);
  }

  // Batch: compute statuses for all plans at once (single txn fetch)
  Future<List<BudgetStatus>> getAllStatuses(List<BudgetPlan> plans) async {
    if (plans.isEmpty) return [];
    final txns = await _txnSvc.getTransactionsList();
    return plans.map((p) => _computeStatus(p, txns)).toList();
  }

  BudgetStatus _computeStatus(
      BudgetPlan plan, List<TransactionModel> txns) {
    final spent = txns
        .where((t) =>
            t.type     == 'expense' &&
            t.category == plan.category &&
            t.date.isAfter(plan.periodStart) &&
            t.date.isBefore(plan.periodEnd))
        .fold(0.0, (s, t) => s + t.amount);

    final effective  = plan.effectiveAmount;
    final remaining  = effective - spent;
    final pct        = effective > 0 ? spent / effective : 0.0;

    return BudgetStatus(
      plan:      plan,
      spent:     spent,
      remaining: remaining,
      pct:       pct,
      isOver:    pct > 1.0,
      isNear:    pct >= 0.8 && pct <= 1.0,
    );
  }

  // ── Rollover: carry unused budget to next month ──────────────────────────
  Future<void> rolloverToNextMonth(BudgetStatus status) async {
    if (!status.plan.rollover || status.remaining <= 0) return;
    final now     = DateTime.now();
    final nextM   = status.plan.month == 12 ? 1  : status.plan.month + 1;
    final nextY   = status.plan.month == 12
        ? status.plan.year + 1 : status.plan.year;

    // Check if a plan for next month already exists for this category
    final uid = _uid;
    if (uid == null) return;
    final existing = await _col
        .where('userId',   isEqualTo: uid)
        .where('category', isEqualTo: status.plan.category)
        .where('month',    isEqualTo: nextM)
        .where('year',     isEqualTo: nextY)
        .get();

    if (existing.docs.isEmpty) {
      // Create new plan for next month with rolled-over amount
      await addPlan(BudgetPlan(
        userId:         uid,
        category:       status.plan.category,
        amount:         status.plan.amount,
        month:          nextM,
        year:           nextY,
        rollover:       status.plan.rollover,
        rolloverAmount: status.remaining,
        emoji:          status.plan.emoji,
      ));
    } else {
      // Update existing plan's rollover amount
      final doc  = existing.docs.first;
      final plan = BudgetPlan.fromFirestore(doc);
      await updatePlan(plan.copyWith(
          rolloverAmount: status.remaining));
    }
  }
}