// lib/screens/force_update_screen.dart
// Full-screen blocking update wall — cannot be dismissed

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/force_update_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppVersionInfo info;
  const ForceUpdateScreen({super.key, required this.info});

  Future<void> _openStore() async {
    if (info.updateUrl.isEmpty) return;
    try {
      final uri = Uri.parse(info.updateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // block back button — cannot dismiss forced update
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.system_update_alt,
                          color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 24),
                    const Text('Update Required',
                        style: TextStyle(
                            color: Colors.white, fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      info.updateMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15, height: 1.5),
                    ),
                    if (info.whatsNew.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.new_releases_outlined,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              const Text("What's New",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ]),
                            const SizedBox(height: 8),
                            Text(info.whatsNew,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      _chip('Your version', info.currentVersion),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 10),
                      _chip('Latest', info.minVersion, highlight: true),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _openStore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 22),
                        label: const Text('Update Now',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'You must update to continue using the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String version, {bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: highlight
                      ? const Color(0xFF667eea)
                      : Colors.white.withOpacity(0.7))),
          Text(version,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: highlight
                      ? const Color(0xFF667eea) : Colors.white)),
        ]),
      );
}