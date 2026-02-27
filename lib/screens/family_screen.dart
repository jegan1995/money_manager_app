import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/family_service.dart';
import '../models/family_model.dart';
import 'family_dashboard_screen.dart';
import 'family_invites_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _svc = FamilyService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Family Mode'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          // Pending invites bell
          StreamBuilder<List<FamilyInvite>>(
            stream: _svc.watchMyInvites(),
            builder: (ctx, snap) {
              final count = snap.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () => Navigator.push(ctx,
                        MaterialPageRoute(
                            builder: (_) =>
                                const FamilyInvitesScreen())),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<FamilyModel?>(
        stream: _svc.watchCurrentFamily(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final family = snap.data;

          if (family == null) {
            return _noFamilyView(isDark);
          }

          return _familyView(family, isDark);
        },
      ),
    );
  }

  // ── No family — create or join ─────────────────────────────────────────────
  Widget _noFamilyView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),

        // Hero illustration
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Family Mode',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Track finances together as a family.\n'
              'See everyone\'s income & expenses in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14, height: 1.5),
            ),
          ]),
        ),

        const SizedBox(height: 32),

        // Features list
        _featureRow(Icons.visibility, 'Shared Dashboard',
            'See all family members\' spending in one view'),
        _featureRow(Icons.bar_chart, 'Family Reports',
            'Combined income, expense & savings analytics'),
        _featureRow(Icons.people, 'Member Management',
            'Add/remove members, assign roles (owner/member/viewer)'),
        _featureRow(Icons.security, 'Privacy Control',
            'Members only see shared data, not each other\'s passwords'),

        const SizedBox(height: 32),

        // Create family button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showCreateDialog(),
            icon: const Icon(Icons.add_home),
            label: const Text('Create a Family Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Check invites
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const FamilyInvitesScreen())),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Check Invitations'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF667eea)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Has family — show family hub ───────────────────────────────────────────
  Widget _familyView(FamilyModel family, bool isDark) {
    final myMember = family.getMember(_uid);
    final isOwner  = family.isOwner(_uid);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(children: [

        // ── Family card ────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text(
                      '${family.members.length} member${family.members.length != 1 ? 's' : ''}  •  '
                      '${myMember?.role.label ?? 'Member'}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12)),
                  ],
                )),
                if (isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('OWNER',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 16),

              // Member avatars row
              Row(children: [
                ...family.members.take(6).map((m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _avatar(m, 20),
                    )),
                if (family.members.length > 6)
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '+${family.members.length - 6}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Quick actions ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _actionCard(
            icon: Icons.dashboard,
            label: 'Family\nDashboard',
            color: const Color(0xFF1565C0),
            isDark: isDark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => FamilyDashboardScreen(
                          family: family))),
          )),
          const SizedBox(width: 12),
          if (isOwner)
            Expanded(child: _actionCard(
              icon: Icons.person_add,
              label: 'Invite\nMember',
              color: const Color(0xFF2E7D32),
              isDark: isDark,
              onTap: () => _showInviteDialog(family),
            )),
          if (!isOwner) ...[
            const SizedBox(width: 0),
            Expanded(child: _actionCard(
              icon: Icons.bar_chart,
              label: 'Family\nReports',
              color: const Color(0xFF7B1FA2),
              isDark: isDark,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => FamilyDashboardScreen(
                            family: family))),
            )),
          ],
        ]),

        const SizedBox(height: 16),

        // ── Members list ───────────────────────────────────────────────
        _sectionLabel('Members', isDark),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            children: family.members.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final isMe = m.uid == _uid;
              return Column(children: [
                ListTile(
                  leading: _avatar(m, 20),
                  title: Row(children: [
                    Text(m.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Color(0xFF667eea),
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  subtitle: Text(m.email,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _roleBadge(m.role),
                      if (isOwner && !isMe && !family.isOwner(m.uid))
                        IconButton(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: Colors.grey),
                          onPressed: () =>
                              _showMemberOptions(family, m),
                        ),
                    ],
                  ),
                ),
                if (i < family.members.length - 1)
                  Divider(height: 1, indent: 72,
                      color: Colors.grey.withOpacity(0.1)),
              ]);
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // ── Pending invites (owner only) ──────────────────────────────
        if (isOwner) ...[
          StreamBuilder<List<FamilyInvite>>(
            stream: _svc.watchSentInvites(family.id),
            builder: (ctx, snap) {
              final invites = snap.data ?? [];
              if (invites.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Pending Invites', isDark),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2530)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8)],
                    ),
                    child: Column(
                      children: invites.asMap().entries.map((e) {
                        final inv = e.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Colors.orange.withOpacity(0.15),
                            child: const Icon(Icons.mail,
                                color: Colors.orange, size: 20),
                          ),
                          title: Text(inv.invitedEmail,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Sent ${DateFormat('dd MMM').format(inv.createdAt)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await _svc.cancelInvite(inv.id);
                              if (mounted) {
                                _snack('Invite cancelled', Colors.orange);
                              }
                            },
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],

        // ── Danger zone ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Danger Zone',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13, color: Colors.red)),
              const SizedBox(height: 10),
              if (!isOwner) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLeave(family,
                        family.getMember(_uid)!),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Leave Family'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
              if (isOwner) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(family),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Delete Family Group'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _avatar(FamilyMember m, double radius) {
    final color = _hexColor(m.avatarColor ?? '#667eea');
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.2),
      child: Text(
        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8),
      ),
    );
  }

  Widget _roleBadge(FamilyRole role) {
    final color = role == FamilyRole.owner
        ? const Color(0xFF667eea)
        : role == FamilyRole.member
            ? const Color(0xFF2E7D32)
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(role.label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(desc,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          )),
        ]),
      );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ),
      );

  Widget _sectionLabel(String label, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.grey[500], letterSpacing: 1.1)),
      );

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF667eea);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Family Group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Family name',
            hintText: 'e.g. Jegan Family',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await _svc.createFamily(name);
                if (mounted) _snack('Family group created!', Colors.green);
              } catch (e) {
                if (mounted) _snack('Error: $e', Colors.red);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(FamilyModel family) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Invite Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email address of the person you want to invite. '
              'They must already have an account.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                hintText: 'member@email.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white),
            onPressed: () async {
              final email = ctrl.text.trim().toLowerCase();
              if (email.isEmpty || !email.contains('@')) return;
              Navigator.pop(context);
              try {
                await _svc.inviteMember(family.id, family.name, email);
                if (mounted) {
                  _snack('Invite sent to $email!', Colors.green);
                }
              } catch (e) {
                if (mounted) _snack('$e', Colors.red);
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  void _showMemberOptions(FamilyModel family, FamilyMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(member.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(member.email,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 16),
            // Role options
            ...FamilyRole.values
                .where((r) => r != FamilyRole.owner)
                .map((r) => ListTile(
                      leading: Icon(
                          r == FamilyRole.member
                              ? Icons.edit
                              : Icons.visibility,
                          color: member.role == r
                              ? const Color(0xFF667eea)
                              : Colors.grey),
                      title: Text(r.label),
                      subtitle: Text(r.description,
                          style: const TextStyle(fontSize: 11)),
                      selected: member.role == r,
                      selectedColor: const Color(0xFF667eea),
                      onTap: () async {
                        Navigator.pop(context);
                        await _svc.changeMemberRole(
                            family.id, member, r);
                        if (mounted) {
                          _snack('Role updated to ${r.label}',
                              Colors.green);
                        }
                      },
                    )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline,
                  color: Colors.red),
              title: const Text('Remove from Family',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _svc.removeMember(family.id, member);
                if (mounted) {
                  _snack('${member.name} removed', Colors.orange);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave(
      FamilyModel family, FamilyMember me) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Family?'),
        content: Text(
            'You will leave "${family.name}" and lose access to family data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.leaveFamily(family.id, me);
      if (mounted) _snack('You left the family', Colors.orange);
    }
  }

  Future<void> _confirmDelete(FamilyModel family) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Family Group?'),
        content: const Text(
            'This will remove all members and delete the group permanently. '
            'Transaction data is NOT deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.deleteFamily(family);
      if (mounted) _snack('Family group deleted', Colors.red);
    }
  }
}