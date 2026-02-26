import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState
    extends State<AdminBroadcastScreen> {
  final _admin   = AdminService();
  final _titleC  = TextEditingController();
  final _msgC    = TextEditingController();
  bool _sending  = false;

  @override
  void dispose() {
    _titleC.dispose();
    _msgC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleC.text.trim().isEmpty || _msgC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter both title and message'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      await _admin.sendBroadcast(
          _titleC.text.trim(), _msgC.text.trim());
      _titleC.clear();
      _msgC.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Broadcast sent to all users!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Broadcast Message'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.purple.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.campaign,
                  color: Colors.purple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This message will be saved to Firestore and visible to all users in their notifications.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Title field
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6)
              ],
            ),
            child: TextField(
              controller: _titleC,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Broadcast Title',
                hintText: 'e.g. New Feature Released!',
                prefixIcon: Icon(Icons.title),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Message field
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2530) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6)
              ],
            ),
            child: TextField(
              controller: _msgC,
              maxLines: 6,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Type your message here...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.message),
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send to All Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}