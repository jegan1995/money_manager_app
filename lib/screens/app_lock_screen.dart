// lib/screens/app_lock_screen.dart
// App lock with TWO methods:
//   1. Biometric (fingerprint / Face ID)
//   2. In-app 4-digit PIN (always available as fallback)
//
// Lock screen UI:
//   - Shows fingerprint button if biometric is enabled
//   - Shows keypad for PIN entry
//   - "Use PIN instead" / "Use Fingerprint" toggle
//   - Auto-prompts biometric on open if enabled

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';

// ── Wrapper — wraps the whole app ─────────────────────────────────────────────
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
      BiometricService.updateLastActive();
    }
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    setState(() => _checking = true);
    final required = await BiometricService.isLockRequired();
    if (!required) {
      await BiometricService.updateLastActive();
      if (mounted) setState(() { _locked = false; _checking = false; });
      return;
    }
    if (mounted) setState(() { _locked = true; _checking = false; });
  }

  void _onUnlocked() {
    BiometricService.updateLastActive();
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
  bool _showPin        = false;
  bool _bioEnabled     = false;
  bool _pinEnabled     = false;
  bool _bioLoading     = false;
  bool _bioFailed      = false;
  String _pin          = '';
  bool _pinWrong       = false;
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _init();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final bio = await BiometricService.isBiometricEnabled();
    final pin = await BiometricService.isPinEnabled();
    if (mounted) setState(() {
      _bioEnabled  = bio;
      _pinEnabled  = pin;
      _showPin     = !bio && pin; // default to PIN if no biometric
    });
    // Auto-trigger biometric on open
    if (bio && mounted) await _tryBiometric();
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
    setState(() {
      _pin       += d;
      _pinWrong  = false;
    });

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
    HapticFeedback.selectionClick();
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
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 48),

            // App logo + title
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Money Manager',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _showPin ? 'Enter your PIN' : 'Tap fingerprint to unlock',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),

            const Spacer(),

            // ── PIN dots ───────────────────────────────────────────────
            if (_showPin) ...[
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                      _pinWrong ? (8 * (_shakeAnim.value < 0.5
                          ? _shakeAnim.value * 2
                          : (1 - _shakeAnim.value) * 2) - 4) : 0,
                      0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (_pinWrong ? Colors.red : Colors.white)
                            : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? (_pinWrong ? Colors.red : Colors.white)
                              : Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_pinWrong) ...[
                const SizedBox(height: 10),
                const Text('Incorrect PIN. Try again.',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 40),

              // Number keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(children: [
                  _keyRow(['1', '2', '3']),
                  const SizedBox(height: 12),
                  _keyRow(['4', '5', '6']),
                  const SizedBox(height: 12),
                  _keyRow(['7', '8', '9']),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                    // Biometric shortcut (if enabled)
                    SizedBox(width: 72, height: 72,
                      child: _bioEnabled
                          ? TextButton(
                              onPressed: () {
                                setState(() => _showPin = false);
                                _tryBiometric();
                              },
                              style: TextButton.styleFrom(
                                shape: const CircleBorder(),
                              ),
                              child: const Icon(Icons.fingerprint,
                                  color: Colors.white60, size: 32),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _keyButton('0'),
                    SizedBox(width: 72, height: 72,
                      child: TextButton(
                        onPressed: _backspace,
                        style: TextButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.backspace_outlined,
                            color: Colors.white60, size: 22),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]

            // ── Biometric screen ───────────────────────────────────────
            else ...[
              GestureDetector(
                onTap: _bioLoading ? null : _tryBiometric,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(
                        _bioLoading ? 0.08 : 0.15),
                    border: Border.all(
                        color: Colors.white.withOpacity(
                            _bioFailed ? 0 : 0.3),
                        width: 2),
                  ),
                  child: _bioLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(Icons.fingerprint,
                          color: _bioFailed
                              ? Colors.red[300]
                              : Colors.white,
                          size: 48),
                ),
              ),
              const SizedBox(height: 16),
              if (_bioFailed)
                Text('Authentication failed',
                    style: TextStyle(
                        color: Colors.red[300], fontSize: 13)),
              if (!_bioFailed && !_bioLoading)
                Text('Touch sensor to unlock',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12)),
              const SizedBox(height: 20),
              // Retry biometric
              if (_bioFailed)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white60, size: 16),
                  label: const Text('Try again',
                      style: TextStyle(color: Colors.white60)),
                ),
            ],

            const Spacer(),

            // ── Bottom toggle ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(children: [
                // Switch between biometric / PIN
                if (_bioEnabled && _pinEnabled)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _showPin = !_showPin;
                      _pin     = '';
                      _pinWrong = false;
                      if (!_showPin) _tryBiometric();
                    }),
                    icon: Icon(
                      _showPin ? Icons.fingerprint : Icons.dialpad,
                      color: Colors.white54, size: 18),
                    label: Text(
                      _showPin
                          ? 'Use Fingerprint instead'
                          : 'Use PIN instead',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  ),

                // PIN only — no bio
                if (!_bioEnabled && _pinEnabled && !_showPin)
                  TextButton.icon(
                    onPressed: () => setState(() => _showPin = true),
                    icon: const Icon(Icons.dialpad,
                        color: Colors.white54, size: 18),
                    label: const Text('Enter PIN',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _keyRow(List<String> keys) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys.map(_keyButton).toList());

  Widget _keyButton(String digit) => SizedBox(
    width: 72, height: 72,
    child: TextButton(
      onPressed: () => _tapDigit(digit),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.08),
        shape: const CircleBorder(),
        foregroundColor: Colors.white,
      ),
      child: Text(digit,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w300,
              color: Colors.white)),
    ),
  );
}

// ── Settings widget (embedded in settings screen) ─────────────────────────────
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile({super.key});
  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  bool         _bioEnabled  = false;
  bool         _pinEnabled  = false;
  bool         _bioAvail    = false;
  bool         _loading     = true;
  int          _timeout     = 1;
  List<String> _bioTypes    = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final bioAvail   = await BiometricService.isBiometricAvailable();
    final bioEnabled = await BiometricService.isBiometricEnabled();
    final pinEnabled = await BiometricService.isPinEnabled();
    final timeout    = await BiometricService.getLockTimeout();
    final types      = await BiometricService.availableTypes();
    if (mounted) setState(() {
      _bioAvail    = bioAvail;
      _bioEnabled  = bioEnabled;
      _pinEnabled  = pinEnabled;
      _timeout     = timeout;
      _bioTypes    = types;
      _loading     = false;
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
      // ── Biometric row ────────────────────────────────────────────────
      _tile(
        icon: Icons.fingerprint,
        iconColor: const Color(0xFF667eea),
        title: _bioTypes.isNotEmpty
            ? _bioTypes.join(' / ')
            : 'Biometric Lock',
        subtitle: _bioAvail
            ? 'Use fingerprint or Face ID'
            : 'Not available on this device',
        trailing: _bioAvail
            ? Switch(
                value: _bioEnabled,
                activeColor: const Color(0xFF667eea),
                onChanged: (v) async {
                  if (v) {
                    final ok = await BiometricService.authenticateBiometric(
                        reason: 'Confirm to enable biometric lock');
                    if (!ok) return;
                  }
                  await BiometricService.setBiometricEnabled(v);
                  setState(() => _bioEnabled = v);
                },
              )
            : const Icon(Icons.block, color: Colors.grey, size: 20),
        isDark: isDark,
      ),

      _divider(isDark),

      // ── PIN row ──────────────────────────────────────────────────────
      _tile(
        icon: Icons.dialpad_outlined,
        iconColor: const Color(0xFF2E7D32),
        title: 'PIN Lock',
        subtitle: _pinEnabled ? 'PIN is set — tap to change' : 'Set a 4-digit PIN',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_pinEnabled)
            GestureDetector(
              onTap: () async {
                await BiometricService.removePin();
                setState(() => _pinEnabled = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Remove',
                    style: TextStyle(fontSize: 11, color: Colors.red,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSetPinDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pinEnabled ? 'Change' : 'Set PIN',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
        isDark: isDark,
      ),

      // ── Timeout (only when either lock active) ────────────────────
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
              Text('Lock app after being in background',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // ── Set PIN dialog ────────────────────────────────────────────────────────
  void _showSetPinDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _SetPinDialog(
        onPinSet: (pin) async {
          await BiometricService.setPin(pin);
          if (mounted) setState(() => _pinEnabled = true);
        },
        isChanging: _pinEnabled,
        existingVerify: _pinEnabled
            ? (p) => BiometricService.verifyPin(p)
            : null,
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isDark,
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
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
            Text(subtitle, style: TextStyle(
                fontSize: 11, color: Colors.grey[400])),
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
}

// ── Set PIN dialog ────────────────────────────────────────────────────────────
class _SetPinDialog extends StatefulWidget {
  final Future<void> Function(String) onPinSet;
  final bool isChanging;
  final Future<bool> Function(String)? existingVerify;

  const _SetPinDialog({
    required this.onPinSet,
    required this.isChanging,
    this.existingVerify,
  });

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  // Steps: verify_old → enter_new → confirm_new
  int    _step     = 0; // 0=verify old (if changing), 1=enter new, 2=confirm
  String _entered  = '';
  String _newPin   = '';
  String _error    = '';

  @override
  void initState() {
    super.initState();
    _step = widget.isChanging ? 0 : 1;
  }

  String get _title {
    if (_step == 0) return 'Enter current PIN';
    if (_step == 1) return 'Enter new PIN';
    return 'Confirm PIN';
  }

  Future<void> _onDigit(String d) async {
    if (_entered.length >= 4) return;
    HapticFeedback.selectionClick();
    final updated = _entered + d;
    setState(() { _entered = updated; _error = ''; });

    if (updated.length == 4) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_step == 0) {
        // Verify old PIN
        final ok = await (widget.existingVerify?.call(updated) ?? Future.value(true));
        if (ok) {
          setState(() { _step = 1; _entered = ''; });
        } else {
          setState(() { _entered = ''; _error = 'Wrong PIN'; });
        }
      } else if (_step == 1) {
        setState(() { _newPin = updated; _step = 2; _entered = ''; });
      } else {
        // Confirm
        if (updated == _newPin) {
          await widget.onPinSet(_newPin);
          if (mounted) Navigator.pop(context);
        } else {
          setState(() { _entered = ''; _error = "PINs don't match"; });
        }
      }
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_entered.isNotEmpty) {
      setState(() => _entered = _entered.substring(0, _entered.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),

          // PIN dots
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _entered.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFF667eea)
                        : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? const Color(0xFF667eea)
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                );
              })),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 24),

          // Keypad
          for (final row in [['1','2','3'],['4','5','6'],['7','8','9']]) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((d) => _pinKey(d)).toList()),
            const SizedBox(height: 10),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            const SizedBox(width: 60),
            _pinKey('0'),
            SizedBox(width: 60, height: 48,
              child: TextButton(
                onPressed: _back,
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
    );
  }

  Widget _pinKey(String d) => SizedBox(
    width: 60, height: 48,
    child: TextButton(
      onPressed: () => _onDigit(d),
      style: TextButton.styleFrom(
        backgroundColor: Colors.grey.withOpacity(0.08),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(d,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w400)),
    ),
  );
}