import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isChangingPin;
  const PinSetupScreen({super.key, this.isChangingPin = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _lockService = AppLockService();
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final avail = await _lockService.isBiometricAvailable();
    final enabled = await _lockService.isBiometricEnabled();
    setState(() {
      _biometricAvailable = avail;
      _biometricEnabled = enabled;
    });
  }

  void _addDigit(String digit) {
    HapticFeedback.lightImpact();
    if (!_confirming) {
      if (_pin.length >= 4) return;
      setState(() => _pin += digit);
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _confirming = true;
            _errorMessage = null;
          });
        });
      }
    } else {
      if (_confirmPin.length >= 4) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length == 4) {
        _finalize();
      }
    }
  }

  void _removeDigit() {
    HapticFeedback.lightImpact();
    if (!_confirming) {
      if (_pin.isEmpty) return;
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else {
      if (_confirmPin.isEmpty) {
        setState(() {
          _confirming = false;
          _confirmPin = '';
        });
        return;
      }
      setState(
          () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
  }

  Future<void> _finalize() async {
    if (_pin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'PINs don\'t match. Try again.';
        _confirmPin = '';
        _confirming = false;
        _pin = '';
      });
      return;
    }
    await _lockService.savePin(_pin);
    if (_biometricEnabled) {
      await _lockService.setBiometricEnabled(true);
    }
    if (mounted) {
      _showSnack('✅ PIN set successfully!', Colors.green);
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPin = _confirming ? _confirmPin : _pin;
    final title = _confirming ? 'Confirm PIN' : 'Set PIN';
    final subtitle = _confirming
        ? 'Enter the same PIN again'
        : widget.isChangingPin
            ? 'Enter a new 4-digit PIN'
            : 'Choose a 4-digit PIN to lock the app';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.isChangingPin ? 'Change PIN' : 'Set App Lock',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Lock icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _confirming ? Icons.lock_outline : Icons.lock_open,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(_errorMessage!,
                  style: TextStyle(color: Colors.red[300], fontSize: 13)),
            ],

            const SizedBox(height: 40),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < currentPin.length;
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
                        color: Colors.white.withOpacity(0.6), width: 1.5),
                  ),
                );
              }),
            ),

            const SizedBox(height: 40),

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
                      const SizedBox(width: 72),
                      _buildDigitButton('0'),
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

            // Biometric toggle
            if (_biometricAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Also enable fingerprint/face unlock',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: _biometricEnabled,
                        onChanged: (v) =>
                            setState(() => _biometricEnabled = v),
                        activeColor: Colors.white,
                        activeTrackColor: Colors.white30,
                      ),
                    ],
                  ),
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
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1),
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