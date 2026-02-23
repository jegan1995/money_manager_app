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
  final _lockService = AppLockService();
  String _enteredPin = '';
  int _failedAttempts = 0;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _bioLoading = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.05, 0),
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    _init();
  }

  Future<void> _init() async {
    final bioAvail = await _lockService.isBiometricAvailable();
    final bioEnabled = await _lockService.isBiometricEnabled();
    final failed = await _lockService.getFailedAttempts();

    if (!mounted) return;
    setState(() {
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
      _failedAttempts = failed;
      _loading = false;
    });

    // Auto-trigger biometric on open if enabled
    if (bioEnabled) {
      // Small delay so screen renders first
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _authenticateBiometric();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });
    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 100), _verifyPin);
    }
  }

  void _removeDigit() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    final correct = await _lockService.verifyPin(_enteredPin);
    if (!mounted) return;

    if (correct) {
      HapticFeedback.heavyImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _enteredPin = '';
        _failedAttempts++;
        _errorMessage = _failedAttempts >= 5
            ? 'Too many attempts — use fingerprint below'
            : 'Wrong PIN — ${5 - _failedAttempts} attempt${5 - _failedAttempts == 1 ? '' : 's'} left';
      });
    }
  }

  Future<void> _authenticateBiometric() async {
    if (_bioLoading) return;
    setState(() {
      _bioLoading = true;
      _errorMessage = null;
    });

    final result = await _lockService.authenticateWithBiometric();

    if (!mounted) return;
    setState(() => _bioLoading = false);

    if (result.success) {
      widget.onUnlocked();
    } else if (result.error != null &&
        result.error != 'Authentication cancelled') {
      setState(() => _errorMessage = result.error);
    }
  }

  bool get _bioButtonActive => _biometricEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFF1565C0),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const SizedBox(height: 52),

                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('💰', style: TextStyle(fontSize: 36))),
                  ),
                  const SizedBox(height: 14),

                  const Text('Money Manager',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),

                  // Status / error message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _errorMessage ?? 'Enter your PIN to unlock',
                      key: ValueKey(_errorMessage),
                      style: TextStyle(
                          color: _errorMessage != null
                              ? Colors.red[300]
                              : Colors.white60,
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 44),

                  // PIN dots with shake animation
                  SlideTransition(
                    position: _shakeAnim,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // PIN pad
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        _buildRow(['1', '2', '3']),
                        const SizedBox(height: 16),
                        _buildRow(['4', '5', '6']),
                        const SizedBox(height: 16),
                        _buildRow(['7', '8', '9']),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Biometric button — FIX: always tappable if enabled
                            GestureDetector(
                              onTap: _bioButtonActive
                                  ? _authenticateBiometric
                                  : null,
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Center(
                                  child: _bioLoading
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5),
                                        )
                                      : Icon(
                                          Icons.fingerprint,
                                          color: _bioButtonActive
                                              ? Colors.white
                                              : Colors.white24,
                                          size: 36,
                                        ),
                                ),
                              ),
                            ),
                            _buildDigitButton('0'),
                            // Backspace
                            GestureDetector(
                              onTap: _removeDigit,
                              child: const SizedBox(
                                width: 72,
                                height: 72,
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

                  const SizedBox(height: 24),

                  // Biometric hint text
                  if (_biometricEnabled)
                    Text(
                      _biometricAvailable
                          ? 'Touch the fingerprint icon to unlock'
                          : 'Fingerprint not set up on this device',
                      style: TextStyle(
                          color: _biometricAvailable
                              ? Colors.white38
                              : Colors.orange[300],
                          fontSize: 12),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: digits.map(_buildDigitButton).toList(),
      );

  Widget _buildDigitButton(String digit) => GestureDetector(
        onTap: () => _addDigit(digit),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
            border: Border.all(
                color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ),
      );
}