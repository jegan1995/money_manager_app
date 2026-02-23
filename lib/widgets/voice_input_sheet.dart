import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_model.dart';
import '../services/voice_input_service.dart';

/// Shows a bottom sheet with mic button.
/// On confirm, returns a VoiceParseResult to the caller.
class VoiceInputSheet extends StatefulWidget {
  final List<AccountModel> accounts;

  const VoiceInputSheet({super.key, required this.accounts});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  final _service = VoiceInputService();
  final _textController = TextEditingController();

  VoiceParseResult? _result;
  bool _listening = false;
  bool _showManualInput = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.25).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Simulate mic (real speech_to_text would go here)
  void _toggleListening() {
    HapticFeedback.mediumImpact();
    setState(() => _listening = !_listening);

    if (!_listening) {
      // When user "stops" show manual input with what was said
      setState(() => _showManualInput = true);
    }
  }

  void _parseInput(String text) {
    if (text.trim().isEmpty) return;
    final result = _service.parse(text, widget.accounts);
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.mic, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('Voice Input',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'Say something like:\n"Add ₹200 petrol expense from SBI account"',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey[600], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Mic button with pulse animation
          if (!_showManualInput) ...[
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _listening ? _pulseAnim.value : 1.0,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening
                        ? Colors.red
                        : theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? Colors.red : theme.colorScheme.primary)
                            .withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _listening ? '🔴 Listening...' : 'Tap mic to speak',
              style: TextStyle(
                color: _listening ? Colors.red : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _showManualInput = true),
              child: const Text('Or type instead'),
            ),
          ],

          // Manual text input (or after mic stops)
          if (_showManualInput) ...[
            TextField(
              controller: _textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. 200 petrol expense sbi',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _parseInput(_textController.text),
                ),
              ),
              onSubmitted: _parseInput,
            ),
            const SizedBox(height: 16),
          ],

          // Parsed result preview
          if (_result != null) ...[
            _buildResultCard(_result!, theme),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _result),
                icon: const Icon(Icons.check),
                label: const Text('Use This'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(VoiceParseResult r, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = r.type == 'income'
        ? Colors.green
        : r.type == 'transfer'
            ? Colors.blue
            : Colors.red;

    // Find account name
    String? accountName;
    if (r.fromAccount != null) {
      try {
        accountName = widget.accounts
            .firstWhere((a) => a.id == r.fromAccount)
            .name;
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Detected',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              // Confidence indicator
              _confidenceBadge(r.confidence),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _row(Icons.swap_vert, 'Type',
              (r.type ?? 'expense').toUpperCase(), typeColor),
          if (r.amount != null)
            _row(Icons.currency_rupee, 'Amount',
                '₹${r.amount!.toStringAsFixed(0)}', Colors.orange),
          if (r.category != null)
            _row(Icons.category, 'Category', r.category!, null),
          if (r.subcategory != null)
            _row(Icons.label, 'Subcategory', r.subcategory!, null),
          if (accountName != null)
            _row(Icons.account_balance_wallet, 'Account', accountName, null),
          if (r.note != null && r.note!.isNotEmpty)
            _row(Icons.notes, 'Note', r.note!, null),
          const SizedBox(height: 8),
          Text(
            '* Review and edit before saving',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(double confidence) {
    Color color;
    String label;
    if (confidence >= 0.7) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.4) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.grey;
      label = 'Low';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}