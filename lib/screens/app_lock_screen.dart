import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final _svc = AppLockService();

  String _pin = '';
  int _failed = 0;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _bioLoading = false;
  String? _message; // null = default hint

  late AnimationController _shake;
  late Animation<Offset> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = Tween<Offset>(
            begin: Offset.zero, end: const Offset(0.06, 0))
        .animate(CurvedAnimation(parent: _shake, curve: Curves.elasticIn));
    _init();
  }

  Future<void> _init() async {
    final bioEnabled = await _svc.isBiometricEnabled();
    final failed = await _svc.getFailedAttempts();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = bioEnabled;
      _failed = failed;
      _loading = false;
    });
    // Auto-trigger if biometric enabled
    if (bioEnabled) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _doBiometric();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() { _pin += d; _message = null; });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 120), _verify);
    }
  }

  void _del() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _message = null; });
  }

  Future<void> _verify() async {
    final ok = await _svc.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.heavyImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      _shake.forward(from: 0);
      setState(() {
        _failed++;
        _pin = '';
        _message = _failed >= 5
            ? 'Too many attempts — tap fingerprint icon'
            : 'Wrong PIN (${_failed}/5)';
      });
    }
  }

  Future<void> _doBiometric() async {
    if (_bioLoading) return;
    setState(() { _bioLoading = true; _message = null; });

    final r = await _svc.authenticateWithBiometric();

    if (!mounted) return;
    setState(() => _bioLoading = false);

    if (r.success) {
      widget.onUnlocked();
    } else if (r.error != null) {
      // Show error in the status line
      setState(() => _message = r.error);
    }
    // null error = user cancelled silently → do nothing
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const SizedBox(height: 56),

                  // App icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('💰', style: TextStyle(fontSize: 38))),
                  ),
                  const SizedBox(height: 14),

                  const Text('Money Manager',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Status message (animates between texts)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _message ?? 'Enter PIN to unlock',
                      key: ValueKey(_message),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message != null
                            ? Colors.red[300]
                            : Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // PIN dots
                  SlideTransition(
                    position: _shakeAnim,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length
                                ? Colors.white
                                : Colors.white.withOpacity(0.22),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.55),
                                width: 1.5),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // PIN pad
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: Column(
                      children: [
                        _row(['1','2','3']),
                        const SizedBox(height: 14),
                        _row(['4','5','6']),
                        const SizedBox(height: 14),
                        _row(['7','8','9']),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ── Fingerprint button ──────────────────────────
                            // Always shown if enabled — tapping triggers auth
                            _bioBtn(),
                            _digit('0'),
                            // ── Backspace ───────────────────────────────────
                            GestureDetector(
                              onTap: _del,
                              child: const SizedBox(
                                width: 72, height: 72,
                                child: Center(
                                  child: Icon(Icons.backspace_outlined,
                                      color: Colors.white, size: 24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Fingerprint hint text
                  if (_biometricEnabled)
                    Text(
                      'Tap 👆 fingerprint icon to use biometric',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _row(List<String> ds) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ds.map(_digit).toList());

  Widget _digit(String d) => GestureDetector(
    onTap: () => _tap(d),
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.11),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Center(
        child: Text(d,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300)),
      ),
    ),
  );

  Widget _bioBtn() {
    if (!_biometricEnabled) {
      // Empty placeholder so layout stays balanced
      return const SizedBox(width: 72, height: 72);
    }
    return GestureDetector(
      onTap: _doBiometric,
      child: SizedBox(
        width: 72, height: 72,
        child: Center(
          child: _bioLoading
              ? const SizedBox(
                  width: 30, height: 30,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.fingerprint, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}