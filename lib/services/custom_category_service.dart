// lib/services/custom_category_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/custom_category_model.dart';

class CustomCategoryService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static const _col = 'custom_categories';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<CustomCategory>> getCategories({required String type}) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    // Single-field filter only (no composite index needed)
    return _db.collection(_col)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => CustomCategory.fromFirestore(d))
          .where((c) => c.type == type) // filter client-side
          .toList()
        ..sort((a, b) {
          if (a.isBuiltIn != b.isBuiltIn) return a.isBuiltIn ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      return list;
    });
  }

  Future<List<CustomCategory>> getCategoriesOnce({required String type}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      // Ensure built-ins are seeded first
      await seedBuiltInIfEmpty(type: type);
      final snap = await _db.collection(_col)
          .where('userId', isEqualTo: uid)
          .get();
      return snap.docs
          .map((d) => CustomCategory.fromFirestore(d))
          .where((c) => c.type == type) // filter client-side
          .toList()
        ..sort((a, b) {
          if (a.isBuiltIn && !b.isBuiltIn) return -1;
          if (!a.isBuiltIn && b.isBuiltIn) return 1;
          return a.name.compareTo(b.name);
        });
    } catch (_) {
      return [];
    }
  }

  Future<void> addCategory(CustomCategory cat) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection(_col).add(CustomCategory(
      userId: uid, type: cat.type, name: cat.name,
      emoji: cat.emoji, color: cat.color,
      subcategories: cat.subcategories, isBuiltIn: false,
    ).toMap());
  }

  Future<void> updateCategory(String id, CustomCategory cat) async {
    await _db.collection(_col).doc(id).update(cat.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection(_col).doc(id).delete();
  }

  Future<void> seedBuiltInIfEmpty({required String type}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final existingSnap = await _db.collection(_col)
          .where('userId', isEqualTo: uid)
          .get();
      final alreadySeeded = existingSnap.docs.any((d) =>
          (d.data() as Map<String, dynamic>)['type'] == type);
      if (alreadySeeded) return;

      final seeds = type == 'expense' ? _expenseSeeds : _incomeSeeds;
      final batch = _db.batch();
      for (final cat in seeds) {
        final ref = _db.collection(_col).doc();
        batch.set(ref, CustomCategory(
          userId: uid,
          type: type,
          name:  cat['name'] as String,
          emoji: cat['emoji'] as String,
          color: cat['color'] as Color,
          subcategories: (cat['subs'] as List)
              .map((s) => CustomSubcategory(
                    name: s['name'] as String,
                    subSubs: List<String>.from(s['sub3'] as List),
                  ))
              .toList(),
          isBuiltIn: true,
        ).toMap());
      }
      await batch.commit();
    } catch (_) {}
  }

  static const _expenseSeeds = [
    {'name':'Food & Dining','emoji':'🍽️','color':Color(0xFFfa709a),'subs':[
      {'name':'Restaurants',   'sub3':['With Friends','With Family','Work Lunch','Date Night']},
      {'name':'Groceries',     'sub3':['Supermarket','Local Market','Online Order']},
      {'name':'Cafes',         'sub3':['Coffee','Tea','Snacks']},
      {'name':'Fast Food',     'sub3':['Breakfast','Lunch','Dinner','Late Night']},
      {'name':'Food Delivery', 'sub3':['Swiggy','Zomato','Other App']},
      {'name':'Breakfast',     'sub3':['Home','Outside','Office']},
      {'name':'Lunch',         'sub3':['Home','Office','Outside']},
      {'name':'Dinner',        'sub3':['Home','Restaurant','Party']},
    ]},
    {'name':'Shopping','emoji':'🛍️','color':Color(0xFFf6d365),'subs':[
      {'name':'Clothing',     'sub3':['Men','Women','Kids','Accessories']},
      {'name':'Electronics',  'sub3':['Phone','Laptop','Accessories','Appliances']},
      {'name':'Books',        'sub3':['Academic','Fiction','Non-Fiction']},
      {'name':'Gifts',        'sub3':['Birthday','Anniversary','Festival']},
      {'name':'Home & Garden','sub3':['Furniture','Decor','Kitchen','Garden']},
      {'name':'Online',       'sub3':['Amazon','Flipkart','Meesho','Other']},
    ]},
    {'name':'Transportation','emoji':'🚗','color':Color(0xFF43b89c),'subs':[
      {'name':'Fuel',                'sub3':['Petrol','Diesel','CNG']},
      {'name':'Public Transport',    'sub3':['Bus','Metro','Train','Auto']},
      {'name':'Cab / Ride Share',    'sub3':['Ola','Uber','Rapido','Other']},
      {'name':'Parking',             'sub3':['Mall','Office','Other']},
      {'name':'Vehicle Maintenance', 'sub3':['Service','Tyres','Repair','Insurance']},
    ]},
    {'name':'Bills & Utilities','emoji':'💡','color':Color(0xFF667eea),'subs':[
      {'name':'Electricity',    'sub3':['Home','Office']},
      {'name':'Water',          'sub3':['Home','Society']},
      {'name':'Internet',       'sub3':['Broadband','Mobile Data']},
      {'name':'Phone',          'sub3':['Prepaid','Postpaid']},
      {'name':'Rent',           'sub3':['House','Office','Parking']},
      {'name':'OTT/Streaming',  'sub3':['Netflix','Prime','Hotstar','Other']},
    ]},
    {'name':'Entertainment','emoji':'🎬','color':Color(0xFFa18cd1),'subs':[
      {'name':'Movies',   'sub3':['Cinema','OTT','Rent']},
      {'name':'Sports',   'sub3':['Cricket','Football','Gym','Other']},
      {'name':'Gaming',   'sub3':['In-App Purchase','Game Buy','Subscription']},
      {'name':'Events',   'sub3':['Concert','Party','Wedding','Festival']},
      {'name':'Hobbies',  'sub3':['Photography','Music','Art','Reading']},
    ]},
    {'name':'Healthcare','emoji':'🏥','color':Color(0xFF30cfd0),'subs':[
      {'name':'Doctor',   'sub3':['GP','Specialist','Dental','Eye']},
      {'name':'Medicine', 'sub3':['Pharmacy','Online','Supplements']},
      {'name':'Gym',      'sub3':['Membership','Personal Training','Equipment']},
      {'name':'Insurance','sub3':['Health','Life','Accident']},
    ]},
    {'name':'Education','emoji':'📚','color':Color(0xFF764ba2),'subs':[
      {'name':'Tuition',    'sub3':['School','College','Private Tutor']},
      {'name':'Courses',    'sub3':['Online','Offline','Certification']},
      {'name':'Books',      'sub3':['Textbooks','Reference','Fiction']},
      {'name':'Stationery', 'sub3':['Pens','Notebooks','Other']},
    ]},
    {'name':'Personal Care','emoji':'💆','color':Color(0xFFfe6b8b),'subs':[
      {'name':'Salon / Barber','sub3':['Haircut','Colouring','Styling']},
      {'name':'Spa',           'sub3':['Massage','Facial','Body']},
      {'name':'Cosmetics',     'sub3':['Skincare','Makeup','Perfume']},
    ]},
    {'name':'Travel','emoji':'✈️','color':Color(0xFF0ba360),'subs':[
      {'name':'Flights', 'sub3':['Domestic','International']},
      {'name':'Hotels',  'sub3':['Business Trip','Leisure','Budget']},
      {'name':'Tours',   'sub3':['Family','Friends','Solo','Work']},
      {'name':'Visa',    'sub3':[]},
    ]},
    {'name':'Other','emoji':'📌','color':Color(0xFF95a5a6),'subs':[
      {'name':'Miscellaneous','sub3':[]},
      {'name':'Cash',         'sub3':[]},
    ]},
  ];

  static const _incomeSeeds = [
    {'name':'Salary','emoji':'💼','color':Color(0xFF43b89c),'subs':[
      {'name':'Monthly Salary','sub3':[]},
      {'name':'Bonus',         'sub3':['Annual','Performance','Festival']},
      {'name':'Overtime',      'sub3':[]},
      {'name':'Arrears',       'sub3':[]},
    ]},
    {'name':'Business','emoji':'🏢','color':Color(0xFF667eea),'subs':[
      {'name':'Sales',       'sub3':['Product','Service']},
      {'name':'Commission',  'sub3':[]},
      {'name':'Partnership', 'sub3':[]},
    ]},
    {'name':'Freelance','emoji':'💻','color':Color(0xFFf6d365),'subs':[
      {'name':'Project Payment','sub3':[]},
      {'name':'Consulting',     'sub3':[]},
      {'name':'Design',         'sub3':[]},
      {'name':'Writing',        'sub3':[]},
    ]},
    {'name':'Investments','emoji':'📈','color':Color(0xFF30cfd0),'subs':[
      {'name':'Dividends',    'sub3':[]},
      {'name':'Interest',     'sub3':['FD','Savings Account','Other']},
      {'name':'Capital Gains','sub3':['Stocks','Mutual Funds','Property']},
    ]},
    {'name':'Gifts','emoji':'🎁','color':Color(0xFFfa709a),'subs':[
      {'name':'Cash Gift',     'sub3':['Birthday','Festival','Wedding']},
      {'name':'Money Transfer','sub3':[]},
    ]},
    {'name':'Other Income','emoji':'💰','color':Color(0xFF95a5a6),'subs':[
      {'name':'Cashback', 'sub3':[]},
      {'name':'Refund',   'sub3':[]},
    ]},
  ];
}