import 'package:flutter/material.dart';

class CategoryIcons {
  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
        return Icons.receipt_long;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'salary':
        return Icons.work;
      case 'business':
        return Icons.business_center;
      case 'investment':
        return Icons.trending_up;
      case 'gift':
        return Icons.card_giftcard;
      default:
        return Icons.category;
    }
  }
  
  static Color getColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'bills':
        return Colors.red;
      case 'entertainment':
        return Colors.pink;
      case 'health':
        return Colors.green;
      case 'education':
        return Colors.indigo;
      case 'salary':
        return Colors.teal;
      case 'business':
        return Colors.brown;
      case 'investment':
        return Colors.deepOrange;
      case 'gift':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
