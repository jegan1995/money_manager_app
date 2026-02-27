import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/family_model.dart';

class FamilyService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid  => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;
  String? get _name  => _auth.currentUser?.displayName;

  // ── Create a new family ────────────────────────────────────────────────────
  Future<String> createFamily(String familyName) async {
    final uid   = _uid!;
    final name  = _name  ?? _email ?? 'Owner';
    final email = _email ?? '';

    final owner = FamilyMember(
      uid:         uid,
      name:        name,
      email:       email,
      role:        FamilyRole.owner,
      joinedAt:    DateTime.now(),
      avatarColor: '#667eea',
    );

    // Create family doc
    final ref = await _db.collection('families').add({
      'name':      familyName,
      'ownerUid':  uid,
      'members':   [owner.toMap()],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Save familyId on user doc
    await _db.collection('users').doc(uid).set(
      {'familyId': ref.id, 'familyRole': 'owner'},
      SetOptions(merge: true),
    );

    return ref.id;
  }

  // ── Get current user's family ──────────────────────────────────────────────
  Future<String?> getCurrentFamilyId() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data()?['familyId'] as String?;
  }

  Stream<FamilyModel?> watchCurrentFamily() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().asyncExpand((userDoc) {
      final familyId = userDoc.data()?['familyId'] as String?;
      if (familyId == null) return Stream.value(null);
      return _db.collection('families').doc(familyId).snapshots().map((doc) {
        if (!doc.exists) return null;
        return FamilyModel.fromFirestore(doc);
      });
    });
  }

  // ── Invite a member by email ───────────────────────────────────────────────
  Future<void> inviteMember(
      String familyId, String familyName, String email) async {
    // Check not already in family
    final family = await _db.collection('families').doc(familyId).get();
    final members =
        (family.data()?['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (members.any((m) => m['email'] == email)) {
      throw Exception('$email is already a family member');
    }

    // Check no pending invite
    final existing = await _db
        .collection('familyInvites')
        .where('familyId', isEqualTo: familyId)
        .where('invitedEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Invite already sent to $email');
    }

    final invite = FamilyInvite(
      id:            '',
      familyId:      familyId,
      familyName:    familyName,
      invitedEmail:  email,
      invitedByName: _name ?? _email ?? 'Owner',
      invitedByUid:  _uid!,
      status:        'pending',
      createdAt:     DateTime.now(),
    );

    await _db.collection('familyInvites').add({
      ...invite.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Get invites for current user ───────────────────────────────────────────
  Stream<List<FamilyInvite>> watchMyInvites() {
    final email = _email;
    if (email == null) return Stream.value([]);
    return _db
        .collection('familyInvites')
        .where('invitedEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FamilyInvite.fromFirestore(d))
            .toList());
  }

  // ── Get pending invites sent by family ────────────────────────────────────
  Stream<List<FamilyInvite>> watchSentInvites(String familyId) {
    return _db
        .collection('familyInvites')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => FamilyInvite.fromFirestore(d))
            .toList());
  }

  // ── Accept invite ──────────────────────────────────────────────────────────
  Future<void> acceptInvite(FamilyInvite invite) async {
    final uid   = _uid!;
    final name  = _name  ?? _email ?? 'Member';
    final email = _email ?? invite.invitedEmail;

    // Check user not already in a family
    final userDoc = await _db.collection('users').doc(uid).get();
    final existingFamily = userDoc.data()?['familyId'];
    if (existingFamily != null) {
      throw Exception(
          'You are already in a family. Leave it first to join another.');
    }

    // Get color for avatar
    final colors = [
      '#E53935', '#FB8C00', '#43A047', '#1E88E5',
      '#8E24AA', '#00ACC1', '#EC407A', '#FF7043',
    ];
    final familyDoc = await _db.collection('families')
        .doc(invite.familyId).get();
    final existingCount =
        (familyDoc.data()?['members'] as List?)?.length ?? 0;
    final color = colors[existingCount % colors.length];

    final newMember = FamilyMember(
      uid:         uid,
      name:        name,
      email:       email,
      role:        FamilyRole.member,
      joinedAt:    DateTime.now(),
      avatarColor: color,
    );

    // Add member to family
    await _db.collection('families').doc(invite.familyId).update({
      'members': FieldValue.arrayUnion([newMember.toMap()]),
    });

    // Update user doc
    await _db.collection('users').doc(uid).set(
      {'familyId': invite.familyId, 'familyRole': 'member'},
      SetOptions(merge: true),
    );

    // Mark invite accepted
    await _db.collection('familyInvites').doc(invite.id)
        .update({'status': 'accepted'});
  }

  // ── Decline invite ─────────────────────────────────────────────────────────
  Future<void> declineInvite(String inviteId) async {
    await _db.collection('familyInvites').doc(inviteId)
        .update({'status': 'declined'});
  }

  // ── Remove a member ────────────────────────────────────────────────────────
  Future<void> removeMember(String familyId, FamilyMember member) async {
    // Remove from family members array
    await _db.collection('families').doc(familyId).update({
      'members': FieldValue.arrayRemove([member.toMap()]),
    });

    // Clear familyId from user doc
    await _db.collection('users').doc(member.uid).update({
      'familyId':   FieldValue.delete(),
      'familyRole': FieldValue.delete(),
    });
  }

  // ── Change member role ─────────────────────────────────────────────────────
  Future<void> changeMemberRole(
      String familyId, FamilyMember member, FamilyRole newRole) async {
    final familyDoc = await _db.collection('families').doc(familyId).get();
    final members = (familyDoc.data()?['members'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final updated = members.map((m) {
      if (m['uid'] == member.uid) {
        return {...m, 'role': newRole.name};
      }
      return m;
    }).toList();

    await _db.collection('families').doc(familyId).update({
      'members': updated,
    });
  }

  // ── Leave family ───────────────────────────────────────────────────────────
  Future<void> leaveFamily(String familyId, FamilyMember member) async {
    await removeMember(familyId, member);
  }

  // ── Delete family (owner only) ─────────────────────────────────────────────
  Future<void> deleteFamily(FamilyModel family) async {
    // Clear all members' familyId
    for (final m in family.members) {
      try {
        await _db.collection('users').doc(m.uid).update({
          'familyId':   FieldValue.delete(),
          'familyRole': FieldValue.delete(),
        });
      } catch (_) {}
    }

    // Delete all pending invites
    final invites = await _db
        .collection('familyInvites')
        .where('familyId', isEqualTo: family.id)
        .get();
    for (final i in invites.docs) {
      await i.reference.delete();
    }

    // Delete family doc
    await _db.collection('families').doc(family.id).delete();
  }

  // ── Get ALL transactions for all family members combined ──────────────────
  Future<List<TransactionModel>> getFamilyTransactions(
      List<String> memberUids) async {
    if (memberUids.isEmpty) return [];

    final List<TransactionModel> all = [];

    // Firestore whereIn supports max 10 items
    final chunks = <List<String>>[];
    for (var i = 0; i < memberUids.length; i += 10) {
      chunks.add(memberUids.sublist(
          i, i + 10 > memberUids.length ? memberUids.length : i + 10));
    }

    for (final chunk in chunks) {
      final snap = await _db
          .collection('transactions')
          .where('userId', whereIn: chunk)
          .get();
      all.addAll(snap.docs
          .map((d) => TransactionModel.fromFirestore(d))
          .toList());
    }

    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  // ── Stream family transactions ─────────────────────────────────────────────
  Stream<List<TransactionModel>> watchFamilyTransactions(
      List<String> memberUids) {
    if (memberUids.isEmpty) return Stream.value([]);
    // Use first 10 (Firestore limit)
    final uids = memberUids.take(10).toList();
    return _db
        .collection('transactions')
        .where('userId', whereIn: uids)
        .snapshots()
        .map((s) {
      final list =
          s.docs.map((d) => TransactionModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ── Cancel pending invite ─────────────────────────────────────────────────
  Future<void> cancelInvite(String inviteId) async {
    await _db.collection('familyInvites').doc(inviteId).delete();
  }
}