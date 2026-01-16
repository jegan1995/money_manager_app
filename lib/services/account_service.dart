import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account.dart';

class AccountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addAccount(Account account) async {
    await _db.collection('accounts').add(account.toMap());
  }

  Stream<List<Account>> getAccounts() {
    return _db.collection('accounts').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList(),
    );
  }

  Future<void> updateAccountBalance(String id, double newBalance) async {
    await _db.collection('accounts').doc(id).update({'balance': newBalance});
  }

  Future<void> deleteAccount(String id) async {
    await _db.collection('accounts').doc(id).delete();
  }
}
