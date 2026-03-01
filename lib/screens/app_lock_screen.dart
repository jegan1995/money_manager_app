// lib/screens/app_lock_screen.dart
// Shows when biometric lock is required.
// Full-screen lock — user must authenticate to proceed.
import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

class AppLockScreen extends StatefulWidget {
  final Widget child; // The app to show after unlock
  const AppLockScreen({super.key, required this.child});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  bool _locked   = false;
  bool _checking = true;
  bool _failed   = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App lifecycle — lock on background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      BiometricService.updateLastActive();
    }
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    setState(() { _checking = true; _failed = false; });
    final required = await BiometricService.isLockRequired();
    if (!required) {
      await BiometricService.updateLastActive();
      setState(() { _locked = false; _checking = false; });
      return;
    }
    setState(() { _locked = true; _checking = false; });
    await _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() { _failed = false; });
    final ok = await BiometricService.authenticate(
      reason: 'Authenticate to open Money Manager',
    );
    if (ok) {
      await BiometricService.updateLastActive();
      setState(() => _locked = false);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashLock();
    if (!_locked) return widget.child;
    return _LockScreen(
      failed: _failed,
      onAuthenticate: _authenticate,
    );
  }
}

// ── Lock UI ───────────────────────────────────────────────────────────────────
class _LockScreen extends StatelessWidget {
  final bool failed;
  final VoidCallback onAuthenticate;
  const _LockScreen({required this.failed, required this.onAuthenticate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.fingerprint,
                      color: Colors.white, size: 50),
                ),
                const SizedBox(height: 28),
                const Text('Money Manager',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  failed
                      ? 'Authentication failed. Try again.'
                      : 'Your app is locked.\nAuthenticate to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: failed
                          ? Colors.red[200]
                          : Colors.white.withOpacity(0.8),
                      fontSize: 15,
                      height: 1.5),
                ),
                const SizedBox(height: 48),
                // Authenticate button
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onAuthenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text('Unlock',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (failed) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onAuthenticate,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLock extends StatelessWidget {
  const _SplashLock();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

// ── Settings Widget (used in settings screen) ─────────────────────────────────
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile({super.key});
  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  bool _enabled     = false;
  bool _available   = false;
  bool _loading     = true;
  int  _timeout     = 1;
  List<String> _types = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled   = await BiometricService.isEnabled();
    final timeout   = await BiometricService.getLockTimeout();
    final types     = await BiometricService.availableTypes();
    if (mounted) setState(() {
      _available = available;
      _enabled   = enabled;
      _timeout   = timeout;
      _types     = types;
      _loading   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (!_available) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.fingerprint, color: Colors.grey, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Biometric Lock',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Not available on this device',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ])),
        ]),
      );
    }

    return Column(children: [
      // Main toggle
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fingerprint,
                color: Color(0xFF667eea), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Biometric Lock',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(_types.isNotEmpty ? _types.join(' / ') : 'Fingerprint / Face ID',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ])),
          Switch(
            value: _enabled,
            activeColor: const Color(0xFF667eea),
            onChanged: (v) async {
              if (v) {
                // Verify once before enabling
                final ok = await BiometricService.authenticate(
                    reason: 'Confirm to enable biometric lock');
                if (!ok) return;
              }
              await BiometricService.setEnabled(v);
              setState(() => _enabled = v);
            },
          ),
        ]),
      ),
      // Timeout picker (only when enabled)
      if (_enabled) ...[
        Divider(height: 1, indent: 64,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const SizedBox(width: 48),
            Text('Lock after: ',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500])),
            ...[1, 2, 5, 15].map((m) => GestureDetector(
              onTap: () async {
                await BiometricService.setLockTimeout(m);
                setState(() => _timeout = m);
              },
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _timeout == m
                      ? const Color(0xFF667eea)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${m}m',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _timeout == m
                            ? Colors.white : Colors.grey)),
              ),
            )),
          ]),
        ),
      ],
    ]);
  }
}