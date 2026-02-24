import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

// Web-only import using conditional import pattern
import 'chart_export_web.dart' if (dart.library.io) 'chart_export_mobile.dart';

class ChartExportButton extends StatelessWidget {
  final GlobalKey chartKey;
  final String filename;

  const ChartExportButton({
    super.key,
    required this.chartKey,
    this.filename = 'chart',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: kIsWeb ? 'Export as Image' : 'Share Chart',
      onPressed: () => _exportChart(context),
    );
  }

  Future<void> _exportChart(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Exporting chart...'),
          ]),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final boundary = chartKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Platform-specific export
      await downloadOrShareChart(pngBytes, '$filename.png');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 16),
              Text(kIsWeb
                  ? 'Chart saved as $filename.png'
                  : 'Chart ready to share!'),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}