import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/family_service.dart';
import '../models/family_model.dart';

class FamilyInvitesScreen extends StatelessWidget {
  const FamilyInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc  = FamilyService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Family Invitations'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<FamilyInvite>>(
        stream: svc.watchMyInvites(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invites = snap.data ?? [];

          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mail_outline,
                        size: 40, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  Text('No pending invitations',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'When someone invites you to their\nfamily group, it will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final inv = invites[i];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2530) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                  border: Border.all(
                      color: const Color(0xFF667eea).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF667eea),
                              Color(0xFF764ba2)
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_alt,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.familyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                            'Invited by ${inv.invitedByName}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500]),
                          ),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('PENDING',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),

                    const SizedBox(height: 14),
                    Divider(height: 1,
                        color: Colors.grey.withOpacity(0.15)),
                    const SizedBox(height: 14),

                    // Info row
                    Row(children: [
                      _infoChip(Icons.person_outline,
                          inv.invitedByName),
                      const SizedBox(width: 10),
                      _infoChip(Icons.calendar_today_outlined,
                          DateFormat('dd MMM yyyy')
                              .format(inv.createdAt)),
                    ]),

                    const SizedBox(height: 16),

                    // What joining means
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF667eea)
                                .withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('By joining this family:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667eea))),
                          const SizedBox(height: 6),
                          _bulletPoint(
                              'Your transactions will be visible to family members'),
                          _bulletPoint(
                              'You can view combined family finances'),
                          _bulletPoint(
                              'Your password & account details stay private'),
                          _bulletPoint(
                              'You can leave the family anytime'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Accept / Decline buttons
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await svc.declineInvite(inv.id);
                            if (context.mounted) {
                              _snack(context, 'Invitation declined',
                                  Colors.grey);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                                color: Colors.red, width: 1.5),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: const Text('Decline',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await svc.acceptInvite(inv);
                              if (context.mounted) {
                                _snack(context,
                                    '🎉 Joined ${inv.familyName}!',
                                    Colors.green);
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _snack(context, '$e', Colors.red);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16),
                              SizedBox(width: 6),
                              Text('Accept & Join',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[500])),
        ]),
      );

  Widget _bulletPoint(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('• ',
              style: TextStyle(
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]))),
        ]),
      );

  void _snack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }
}