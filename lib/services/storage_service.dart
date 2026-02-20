import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Upload receipt image
  Future<String?> uploadReceipt(
      Uint8List imageData, String transactionId) async {
    if (_currentUserId == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'receipts/$_currentUserId/$transactionId/$timestamp.jpg';

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading receipt: $e');
      return null;
    }
  }

  // Delete receipt
  Future<void> deleteReceipt(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting receipt: $e');
    }
  }

  // Get receipt URL
  Future<String?> getReceiptUrl(String transactionId) async {
    if (_currentUserId == null) return null;

    try {
      final listResult = await _storage
          .ref()
          .child('receipts/$_currentUserId/$transactionId')
          .listAll();

      if (listResult.items.isNotEmpty) {
        return await listResult.items.first.getDownloadURL();
      }
      return null;
    } catch (e) {
      print('Error getting receipt: $e');
      return null;
    }
  }
}
