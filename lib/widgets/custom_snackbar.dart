import 'package:flutter/material.dart';

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Don't show if context is no longer mounted
    if (!context.mounted) return;

    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = const Color(0xFFC62828);
        icon = Icons.error_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = const Color(0xFFE65100);
        icon = Icons.warning_rounded;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = const Color(0xFF1565C0);
        icon = Icons.info_rounded;
        break;
    }

    // Clear any existing snackbars first to prevent stacking
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        duration: duration,
        // No dismiss action — avoids stale context crash after Navigator.pop()
        // Snackbar auto-dismisses after `duration`
      ),
    );
  }
}

enum SnackBarType { success, error, warning, info }