// lib/screens/app_lock_screen.dart
// FIX: markUnlocked() only called after SUCCESSFUL unlock — not on every check.
// FIX: BiometricSettingsTile uses confirmWithBiometricForSetup() to enable biometric
//      instead of authenticateBiometric() which required it to already be enabled.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';

// ── Wrapper ───────────────────────────────────────────────────────────────────
class AppLockScreen extends StatefulWidget {
  final Widget child;
  const AppLockScreen({super.key, required this.child});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  bool _locked   = false;
  bool _checking = true;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Record when app went to background
      BiometricService.markBackgrounded();
    }
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    setState(() => _checking = true);
    final required = await BiometricService.isLockRequired();
    if (!required) {
      // ── FIX: Only call markUnlocked if no lock is needed at all ─────────────
      // Do NOT reset the timer here — just let user through without locking.
      // markUnlocked() is called after successful biometric/PIN verification.
      // If no lock enabled at all, mark as active so timer works correctly.
      final anyLock = await BiometricService.isAnyLockEnabled();
      if (!anyLock) await BiometricService.markUnlocked();
      if (mounted) setState(() { _locked = false; _checking = false; });
      return;
    }
    if (mounted) setState(() { _locked = true; _checking = false; });
  }

  void _onUnlocked() {
    // ── FIX: markUnlocked only on actual successful auth ─────────────────────
    BiometricService.markUnlocked();
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(
        body: Center(child: CircularProgressIndicator()));
    if (!_locked) return widget.child;
    return _LockUI(onUnlocked: _onUnlocked);
  }
}

// ── Lock UI ───────────────────────────────────────────────────────────────────
class _LockUI extends StatefulWidget {
  final VoidCallback onUnlocked;
  const _LockUI({required this.onUnlocked});
  @override
  State<_LockUI> createState() => _LockUIState();
}

class _LockUIState extends State<_LockUI> with SingleTickerProviderStateMixin {
  bool   _showPin    = false;
  bool   _bioEnabled = false;
  bool   _pinEnabled = false;
  bool   _bioLoading = false;
  bool   _bioFailed  = false;
  String _pin        = '';
  bool   _pinWrong   = false;
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _init();
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    final bio = await BiometricService.isBiometricEnabled();
    final pin = await BiometricService.isPinEnabled();
    if (mounted) setState(() {
      _bioEnabled = bio;
      _pinEnabled = pin;
      _showPin    = !bio; // show PIN pad if no biometric
    });
    if (bio) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    setState(() { _bioLoading = true; _bioFailed = false; });
    final ok = await BiometricService.authenticateBiometric();
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() { _bioLoading = false; _bioFailed = true; });
    }
  }

  Future<void> _tapDigit(String d) async {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() { _pin += d; _pinWrong = false; });

    if (_pin.length == 4) {
      await Future.delayed(const Duration(milliseconds: 80));
      final ok = await BiometricService.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked();
      } else {
        HapticFeedback.vibrate();
        _shakeCtrl.forward(from: 0);
        setState(() { _pin = ''; _pinWrong = true; });
      }
    }
  }

  void _backspace() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(child: Column(children: [
          const SizedBox(height: 48),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          const Text('Money Manager',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _showPin ? 'Enter your 4-digit PIN'
                     : 'Touch fingerprint to unlock',
            style: TextStyle(
                color: Colors.white.withOpacity(0.55), fontSize: 13),
          ),
          const Spacer(),

          // ── PIN view ────────────────────────────────────────────────
          if (_showPin) ...[
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_pinWrong ? (6 * ((_shakeAnim.value % 0.25) / 0.25 - 0.5) * 2) : 0, 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? (_pinWrong ? Colors.red : Colors.white)
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length
                          ? (_pinWrong ? Colors.red : Colors.white)
                          : Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                )),
              ),
            ),
            if (_pinWrong) ...[
              const SizedBox(height: 10),
              const Text('Incorrect PIN',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(children: [
                _keyRow(['1', '2', '3']),
                const SizedBox(height: 14),
                _keyRow(['4', '5', '6']),
                const SizedBox(height: 14),
                _keyRow(['7', '8', '9']),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                  // Fingerprint shortcut
                  SizedBox(width: 72, height: 72,
                    child: _bioEnabled
                        ? TextButton(
                            onPressed: () {
                              setState(() { _showPin = false; _pin = ''; });
                              _tryBiometric();
                            },
                            style: TextButton.styleFrom(shape: const CircleBorder()),
                            child: const Icon(Icons.fingerprint,
                                color: Colors.white60, size: 32),
                          )
                        : const SizedBox.shrink()),
                  _keyButton('0'),
                  SizedBox(width: 72, height: 72,
                    child: TextButton(
                      onPressed: _backspace,
                      style: TextButton.styleFrom(shape: const CircleBorder()),
                      child: const Icon(Icons.backspace_outlined,
                          color: Colors.white60, size: 22),
                    )),
                ]),
              ]),
            ),
          ]

          // ── Biometric view ──────────────────────────────────────────
          else ...[
            GestureDetector(
              onTap: _bioLoading ? null : _tryBiometric,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(_bioLoading ? 0.07 : 0.13),
                  border: Border.all(
                    color: _bioFailed
                        ? Colors.red.withOpacity(0.5)
                        : Colors.white.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                child: _bioLoading
                    ? const Padding(padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.fingerprint,
                        color: _bioFailed ? Colors.red[300] : Colors.white,
                        size: 48),
              ),
            ),
            const SizedBox(height: 12),
            if (_bioFailed)
              Text('Authentication failed',
                  style: TextStyle(color: Colors.red[300], fontSize: 13)),
            if (_bioFailed) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                label: const Text('Try again',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ],

          const Spacer(),

          // ── Bottom toggle PIN ↔ Biometric ─────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: Column(children: [
              if (_bioEnabled && _pinEnabled)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPin = !_showPin;
                      _pin     = '';
                      _pinWrong = false;
                      if (!_showPin) _tryBiometric();
                    });
                  },
                  icon: Icon(_showPin ? Icons.fingerprint : Icons.dialpad,
                      color: Colors.white38, size: 18),
                  label: Text(
                    _showPin ? 'Use Fingerprint instead'
                             : 'Use PIN instead',
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              if (!_bioEnabled && _pinEnabled && !_showPin)
                TextButton.icon(
                  onPressed: () => setState(() => _showPin = true),
                  icon: const Icon(Icons.dialpad, color: Colors.white38, size: 18),
                  label: const Text('Enter PIN',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
            ]),
          ),
        ])),
      ),
    );
  }

  Widget _keyRow(List<String> keys) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys.map(_keyButton).toList());

  Widget _keyButton(String d) => SizedBox(
    width: 72, height: 72,
    child: TextButton(
      onPressed: () => _tapDigit(d),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.07),
        shape: const CircleBorder(),
        foregroundColor: Colors.white,
      ),
      child: Text(d, style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white)),
    ),
  );
}

// ── Settings tile (embedded in settings screen) ───────────────────────────────
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile({super.key});
  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  bool         _bioEnabled = false;
  bool         _pinEnabled = false;
  bool         _bioAvail   = false;
  bool         _loading    = true;
  int          _timeout    = 1;
  List<String> _bioTypes   = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final avail    = await BiometricService.isBiometricAvailable();
    final bioOn    = await BiometricService.isBiometricEnabled();
    final pinOn    = await BiometricService.isPinEnabled();
    final timeout  = await BiometricService.getLockTimeout();
    final types    = await BiometricService.availableTypes();
    if (mounted) setState(() {
      _bioAvail   = avail;
      _bioEnabled = bioOn;
      _pinEnabled = pinOn;
      _timeout    = timeout;
      _bioTypes   = types;
      _loading    = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))));

    return Column(children: [

      // ── Biometric row ──────────────────────────────────────────────
      _settingRow(
        icon: Icons.fingerprint,
        iconColor: const Color(0xFF667eea),
        title: _bioTypes.isNotEmpty ? _bioTypes.join(' / ') : 'Biometric Lock',
        subtitle: _bioAvail
            ? (_bioEnabled ? 'Tap fingerprint or Face ID to unlock' : 'Fingerprint / Face ID')
            : 'Not available on this device',
        trailing: _bioAvail
            ? Switch(
                value: _bioEnabled,
                activeColor: const Color(0xFF667eea),
                onChanged: (v) async {
                  if (v) {
                    // ── FIX: Use confirmWithBiometricForSetup() NOT authenticateBiometric()
                    // authenticateBiometric() checks isBiometricEnabled() first → returns
                    // false immediately → toggle could never be turned ON. Fixed.
                    final ok = await BiometricService.confirmWithBiometricForSetup();
                    if (!ok) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Biometric verification failed'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }
                  }
                  await BiometricService.setBiometricEnabled(v);
                  if (mounted) setState(() => _bioEnabled = v);
                },
              )
            : const Icon(Icons.block, color: Colors.grey, size: 20),
        isDark: isDark,
      ),

      _divider(isDark),

      // ── PIN row ────────────────────────────────────────────────────
      _settingRow(
        icon: Icons.dialpad_outlined,
        iconColor: const Color(0xFF2E7D32),
        title: 'PIN Lock',
        subtitle: _pinEnabled ? 'PIN is set' : 'Set a 4-digit PIN',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_pinEnabled) ...[
            _chip('Remove', Colors.red, () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove PIN'),
                  content: const Text('Are you sure you want to remove your PIN lock?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await BiometricService.removePin();
                if (mounted) setState(() => _pinEnabled = false);
              }
            }),
            const SizedBox(width: 6),
          ],
          _chip(
            _pinEnabled ? 'Change' : 'Set PIN',
            const Color(0xFF2E7D32),
            () => _showSetPinSheet(context),
          ),
        ]),
        isDark: isDark,
      ),

      // ── Auto-lock timeout ──────────────────────────────────────────
      if (_bioEnabled || _pinEnabled) ...[
        _divider(isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timer_outlined,
                  color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Auto-lock after',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Lock when app goes to background',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ])),
            Row(children: [1, 2, 5, 15].map((m) =>
              GestureDetector(
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
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: _timeout == m ? Colors.white : Colors.grey)),
                ),
              )
            ).toList()),
          ]),
        ),
      ],
    ]);
  }

  void _showSetPinSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetPinSheet(
        isChanging: _pinEnabled,
        onPinSet: (pin) async {
          await BiometricService.setPin(pin);
          if (mounted) setState(() => _pinEnabled = true);
        },
      ),
    );
  }

  Widget _settingRow({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required Widget trailing, required bool isDark,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ])),
          trailing,
        ]),
      );

  Widget _divider(bool isDark) => Divider(
    height: 1, indent: 64,
    color: isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.grey.shade100,
  );

  Widget _chip(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: color,
                  fontWeight: FontWeight.bold)),
        ),
      );
}

// ── Set PIN bottom sheet ──────────────────────────────────────────────────────
class _SetPinSheet extends StatefulWidget {
  final bool isChanging;
  final Future<void> Function(String) onPinSet;
  const _SetPinSheet({required this.isChanging, required this.onPinSet});
  @override
  State<_SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends State<_SetPinSheet> {
  // step 0 = verify old (if changing), 1 = enter new, 2 = confirm
  int    _step    = 0;
  String _entered = '';
  String _newPin  = '';
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _step = widget.isChanging ? 0 : 1;
  }

  String get _title => switch (_step) {
    0 => 'Enter current PIN',
    1 => 'Enter new PIN',
    _ => 'Confirm PIN',
  };

  Future<void> _onDigit(String d) async {
    if (_entered.length >= 4) return;
    HapticFeedback.selectionClick();
    final updated = _entered + d;
    setState(() { _entered = updated; _error = ''; });

    if (updated.length == 4) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      if (_step == 0) {
        final ok = await BiometricService.verifyPin(updated);
        if (ok) setState(() { _step = 1; _entered = ''; });
        else    setState(() { _entered = ''; _error = 'Wrong PIN'; });
      } else if (_step == 1) {
        setState(() { _newPin = updated; _step = 2; _entered = ''; });
      } else {
        if (updated == _newPin) {
          await widget.onPinSet(_newPin);
          if (mounted) Navigator.pop(context);
        } else {
          setState(() { _entered = ''; _error = "PINs don't match"; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? const Color(0xFF1E2530) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const Icon(Icons.lock_outline, size: 32, color: Color(0xFF667eea)),
            const SizedBox(height: 12),
            Text(_title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            // Dots
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _entered.length
                        ? const Color(0xFF667eea) : Colors.transparent,
                    border: Border.all(
                      color: i < _entered.length
                          ? const Color(0xFF667eea) : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                ))),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(
                  color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 28),
            // Keypad
            for (final row in [
              ['1','2','3'], ['4','5','6'], ['7','8','9']
            ]) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map(_pinKey).toList()),
              const SizedBox(height: 12),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              const SizedBox(width: 72),
              _pinKey('0'),
              SizedBox(width: 72, height: 52,
                child: TextButton(
                  onPressed: () {
                    if (_entered.isNotEmpty) setState(() =>
                        _entered = _entered.substring(0, _entered.length - 1));
                  },
                  child: const Icon(Icons.backspace_outlined,
                      size: 20, color: Colors.grey),
                )),
            ]),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pinKey(String d) => SizedBox(
    width: 72, height: 52,
    child: TextButton(
      onPressed: () => _onDigit(d),
      style: TextButton.styleFrom(
        backgroundColor: Colors.grey.withOpacity(0.08),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(d,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w400)),
    ),
  );
}