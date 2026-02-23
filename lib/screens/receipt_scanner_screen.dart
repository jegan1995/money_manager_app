import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/receipt_scanner_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with TickerProviderStateMixin {
  final _scanner = ReceiptScannerService();
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _scanning = false;
  ScannedReceiptData? _result;
  String? _pickError;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _scanLineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _scanLineAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanLineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    setState(() => _pickError = null);
    try {
      final f = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 88,
      );
      if (f != null) {
        final bytes = await f.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _result = null;
        });
        _doScan(bytes);
      }
    } catch (e) {
      setState(() => _pickError = 'Camera error: $e');
    }
  }

  Future<void> _pickGallery() async {
    setState(() => _pickError = null);
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 88,
      );
      if (f != null) {
        final bytes = await f.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _result = null;
        });
        _doScan(bytes);
      }
    } catch (e) {
      setState(() => _pickError = 'Gallery error: $e');
    }
  }

  Future<void> _doScan(Uint8List bytes) async {
    setState(() => _scanning = true);
    final result = await _scanner.scanReceipt(bytes);
    if (mounted) setState(() { _scanning = false; _result = result; });
  }

  void _confirm() {
    Navigator.pop(context, _result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        actions: [
          if (_imageBytes != null && !_scanning)
            TextButton.icon(
              onPressed: _pickCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Rescan'),
            ),
        ],
      ),
      body: _imageBytes == null
          ? _buildPickerUI(isDark)
          : _buildScanUI(isDark),
    );
  }

  // ── No image yet — pick source ────────────────────────────────────────────
  Widget _buildPickerUI(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                        width: 2),
                  ),
                  child: const Center(
                    child: Text('🧾', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Scan a Receipt',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Take a photo or pick from gallery.\nGemini AI will auto-fill your transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 36),

            if (_pickError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_pickError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // Camera button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Gallery button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'Powered by Gemini AI Vision',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Image picked — show scan / result ────────────────────────────────────
  Widget _buildScanUI(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Image preview with scan animation overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.memory(
                  _imageBytes!,
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                ),
                if (_scanning)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedBuilder(
                        animation: _scanLineAnim,
                        builder: (_, __) => CustomPaint(
                          painter: _ScanLinePainter(_scanLineAnim.value),
                        ),
                      ),
                    ),
                  ),
                if (_scanning)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                          const SizedBox(height: 10),
                          const Text('Reading receipt...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Gemini AI is analysing',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Results
          if (_result != null) ...[
            if (!_result!.success)
              _errorCard(_result!.error ?? 'Scan failed', isDark)
            else
              _resultCard(isDark),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(String msg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('❌', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          const Text('Could not extract receipt data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(bool isDark) {
    final r = _result!;
    final hasData = r.amount != null || r.merchant != null || r.category != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receipt scanned successfully!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 13)),
                    Text(
                      hasData
                          ? 'Review the extracted data below and confirm.'
                          : 'Limited data found. Fill in manually.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 16),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Extracted data
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2530) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              if (r.amount != null)
                _dataRow('💰', 'Amount', '₹${r.amount!.toStringAsFixed(2)}',
                    Colors.green, isDark),
              if (r.merchant != null) ...[
                const Divider(height: 1),
                _dataRow('🏪', 'Merchant', r.merchant!, Colors.blue, isDark),
              ],
              if (r.category != null) ...[
                const Divider(height: 1),
                _dataRow('🗂️', 'Category', r.category!, Colors.purple, isDark),
              ],
              if (r.date != null) ...[
                const Divider(height: 1),
                _dataRow('📅', 'Date', _formatDate(r.date!), Colors.orange, isDark),
              ],
              if (r.paymentMethod != null) ...[
                const Divider(height: 1),
                _dataRow('💳', 'Payment', r.paymentMethod!, Colors.teal, isDark),
              ],
              if (r.note != null) ...[
                const Divider(height: 1),
                _dataRow('📝', 'Note', r.note!, Colors.grey, isDark),
              ],
            ],
          ),
        ),

        if (!hasData) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: For best results, take a clear photo in good lighting, focusing on the total amount section.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _imageBytes = null;
                    _result = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Scan Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Use This Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dataRow(String emoji, String label, String value, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

// Scanning line painter
class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Glow
    paint.color = Colors.greenAccent.withOpacity(0.2);
    paint.strokeWidth = 12;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}