import 'package:flutter/material.dart';

// Photo receipt feature disabled - placeholder widget
class ReceiptPicker extends StatelessWidget {
  final Function(String?)? onImageSelected;
  
  const ReceiptPicker({super.key, this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
