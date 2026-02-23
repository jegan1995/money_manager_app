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
  bool _shaking = false;
  bool _loading = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _init();
  }

  Future<void> _init() async {
    final bioAvail = await _lockService.isBiometricAvailable();
    final bioEnabled = await _lockService.isBiometricEnabled();
    final failed = await _lockService.getFailedAttempts();
    setState(() {
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
      _failedAttempts = failed;
      _loading = false;
    });

    // Auto-trigger biometric on open
    if (bioAvail && bioEnabled) {
      _authenticateBiometric();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() => _enteredPin += digit);
    HapticFeedback.lightImpact();
    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _removeDigit() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    HapticFeedback.lightImpact();
  }

  Future<void> _verifyPin() async {
    final correct = await _lockService.verifyPin(_enteredPin);
    if (correct) {
      HapticFeedback.heavyImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _enteredPin = '';
        _failedAttempts++;
        _shaking = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _shaking = false);
      });
    }
  }

  Future<void> _authenticateBiometric() async {
    final result = await _lockService.authenticateWithBiometric();
    if (result && mounted) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFF1565C0),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const SizedBox(height: 60),

                  // App icon + title
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child:
                          Text('💰', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Money Manager',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _failedAttempts > 0
                        ? '$_failedAttempts failed attempt${_failedAttempts > 1 ? 's' : ''}'
                        : 'Enter your PIN to unlock',
                    style: TextStyle(
                        color: _failedAttempts > 0
                            ? Colors.red[300]
                            : Colors.white60,
                        fontSize: 14),
                  ),

                  const SizedBox(height: 48),

                  // PIN dots
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) {
                      final dx = _shaking
                          ? 12 *
                              (0.5 - _shakeAnim.value).abs() *
                              (_shakeAnim.value > 0.5 ? 1 : -1)
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(dx * 10, 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < _enteredPin.length;
                        return Container(
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

                  const SizedBox(height: 48),

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
                        // Bottom row: biometric | 0 | backspace
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Biometric button
                            _buildActionButton(
                              child: Icon(
                                Icons.fingerprint,
                                color: (_biometricAvailable && _biometricEnabled)
                                    ? Colors.white
                                    : Colors.white24,
                                size: 30,
                              ),
                              onTap: (_biometricAvailable && _biometricEnabled)
                                  ? _authenticateBiometric
                                  : null,
                            ),
                            _buildDigitButton('0'),
                            // Backspace
                            _buildActionButton(
                              child: const Icon(Icons.backspace_outlined,
                                  color: Colors.white, size: 24),
                              onTap: _removeDigit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Too many attempts
                  if (_failedAttempts >= 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Too many attempts. Use biometric or reinstall app.',
                        style: TextStyle(
                            color: Colors.red[300],
                            fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildActionButton(
      {required Widget child, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(child: child),
        ),
      );
}