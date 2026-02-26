import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PwaInstallScreen extends StatelessWidget {
  const PwaInstallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Install App'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Hero ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('💰', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Install Money Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Install as an app on your phone —\nworks offline, no App Store needed!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── iOS Instructions ─────────────────────────────────────────────
          _platformCard(
            isDark: isDark,
            icon: '🍎',
            title: 'Install on iPhone / iPad',
            subtitle: 'Safari browser required',
            color: const Color(0xFF1565C0),
            steps: const [
              _Step('1', 'Open this page in Safari',
                  'Must use Safari — Chrome/Firefox won\'t work for iOS install'),
              _Step('2', 'Tap the Share button',
                  'The Share icon is at the bottom of Safari (box with arrow)'),
              _Step('3', 'Tap "Add to Home Screen"',
                  'Scroll down in the share menu to find this option'),
              _Step('4', 'Tap "Add"',
                  'The app icon appears on your home screen instantly!'),
            ],
          ),

          const SizedBox(height: 16),

          // ── Android Instructions ─────────────────────────────────────────
          _platformCard(
            isDark: isDark,
            icon: '🤖',
            title: 'Install on Android',
            subtitle: 'Chrome browser recommended',
            color: const Color(0xFF2E7D32),
            steps: const [
              _Step('1', 'Open in Chrome',
                  'Open the app URL in Google Chrome browser'),
              _Step('2', 'Tap the 3-dot menu',
                  'Top right corner of Chrome'),
              _Step('3', 'Tap "Add to Home Screen"',
                  'Or Chrome may show an install banner automatically'),
              _Step('4', 'Tap "Install"',
                  'App installs instantly — no Play Store needed!'),
            ],
          ),

          const SizedBox(height: 16),

          // ── Benefits card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why install?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 14),
                _benefit('⚡', 'Faster loading',
                    'Opens instantly from home screen'),
                _benefit('📵', 'Works offline',
                    'View transactions even without internet'),
                _benefit('🔔', 'Full screen',
                    'No browser address bar — feels like native app'),
                _benefit('🆓', '100% Free',
                    'No App Store, no Play Store, no fees'),
                _benefit('🔄', 'Always updated',
                    'Gets updates automatically when you\'re online'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Share URL card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.link, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text('App URL',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Expanded(
                      child: Text(
                        'money-manager-jegan-2026.web.app',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this link with anyone — they can install it too!',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _platformCard({
    required bool isDark,
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<_Step> steps,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: color.withOpacity(0.15))),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          ),
          // Steps
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: steps
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Center(
                                child: Text(s.num,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(s.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  if (s.desc.isNotEmpty)
                                    Text(s.desc,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String icon, String title, String desc) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(desc,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ]),
      );
}

class _Step {
  final String num;
  final String title;
  final String desc;
  const _Step(this.num, this.title, this.desc);
}