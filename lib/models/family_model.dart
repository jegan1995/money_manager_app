import 'package:cloud_firestore/cloud_firestore.dart';

// ── Family roles ──────────────────────────────────────────────────────────────
enum FamilyRole { owner, member, viewer }

extension FamilyRoleExt on FamilyRole {
  String get name {
    switch (this) {
      case FamilyRole.owner:  return 'owner';
      case FamilyRole.member: return 'member';
      case FamilyRole.viewer: return 'viewer';
    }
  }
  String get label {
    switch (this) {
      case FamilyRole.owner:  return 'Owner';
      case FamilyRole.member: return 'Member';
      case FamilyRole.viewer: return 'Viewer';
    }
  }
  String get description {
    switch (this) {
      case FamilyRole.owner:  return 'Full control — manage members & view all';
      case FamilyRole.member: return 'Add transactions & view family data';
      case FamilyRole.viewer: return 'View only — cannot add transactions';
    }
  }
}

FamilyRole familyRoleFromString(String s) {
  switch (s) {
    case 'owner':  return FamilyRole.owner;
    case 'member': return FamilyRole.member;
    default:       return FamilyRole.viewer;
  }
}

// ── Family member ─────────────────────────────────────────────────────────────
class FamilyMember {
  final String uid;
  final String name;
  final String email;
  final FamilyRole role;
  final DateTime joinedAt;
  final String? avatarColor;

  FamilyMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.avatarColor,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> m) => FamilyMember(
        uid:         m['uid']         ?? '',
        name:        m['name']        ?? 'Unknown',
        email:       m['email']       ?? '',
        role:        familyRoleFromString(m['role'] ?? 'member'),
        joinedAt:    (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        avatarColor: m['avatarColor'],
      );

  Map<String, dynamic> toMap() => {
        'uid':         uid,
        'name':        name,
        'email':       email,
        'role':        role.name,
        'joinedAt':    Timestamp.fromDate(joinedAt),
        'avatarColor': avatarColor,
      };
}

// ── Family invite ─────────────────────────────────────────────────────────────
class FamilyInvite {
  final String id;
  final String familyId;
  final String familyName;
  final String invitedEmail;
  final String invitedByName;
  final String invitedByUid;
  final String status; // pending / accepted / declined
  final DateTime createdAt;

  FamilyInvite({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.invitedEmail,
    required this.invitedByName,
    required this.invitedByUid,
    required this.status,
    required this.createdAt,
  });

  factory FamilyInvite.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return FamilyInvite(
      id:            doc.id,
      familyId:      d['familyId']      ?? '',
      familyName:    d['familyName']    ?? '',
      invitedEmail:  d['invitedEmail']  ?? '',
      invitedByName: d['invitedByName'] ?? '',
      invitedByUid:  d['invitedByUid']  ?? '',
      status:        d['status']        ?? 'pending',
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'familyId':      familyId,
        'familyName':    familyName,
        'invitedEmail':  invitedEmail,
        'invitedByName': invitedByName,
        'invitedByUid':  invitedByUid,
        'status':        status,
        'createdAt':     Timestamp.fromDate(createdAt),
      };
}

// ── Family ────────────────────────────────────────────────────────────────────
class FamilyModel {
  final String id;
  final String name;
  final String ownerUid;
  final List<FamilyMember> members;
  final DateTime createdAt;

  FamilyModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.members,
    required this.createdAt,
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawMembers = d['members'] as List<dynamic>? ?? [];
    return FamilyModel(
      id:        doc.id,
      name:      d['name']     ?? 'My Family',
      ownerUid:  d['ownerUid'] ?? '',
      members:   rawMembers
          .map((m) => FamilyMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name':      name,
        'ownerUid':  ownerUid,
        'members':   members.map((m) => m.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  FamilyMember? getMember(String uid) {
    try {
      return members.firstWhere((m) => m.uid == uid);
    } catch (_) {
      return null;
    }
  }

  bool isOwner(String uid) => ownerUid == uid;
  bool isMember(String uid) => members.any((m) => m.uid == uid);
}