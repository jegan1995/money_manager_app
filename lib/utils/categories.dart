class Categories {
  // Main categories for expense
  static const List<String> expenseCategories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Personal Care',
    'Travel',
    'Other',
  ];

  // Main categories for income
  static const List<String> incomeCategories = [
    'Salary',
    'Business',
    'Investments',
    'Gifts',
    'Freelance',
    'Rental Income',
    'Other',
  ];

  // Main categories for transfer (not used but for completeness)
  static const List<String> transferCategories = [
    'Transfer',
  ];

  // Get main categories based on transaction type
  static List<String> getMainCategories(String type) {
    switch (type.toLowerCase()) {
      case 'income':
        return incomeCategories;
      case 'transfer':
        return transferCategories;
      case 'expense':
      default:
        return expenseCategories;
    }
  }

  // Get subcategories for a given type and category
  static List<String> getSubcategories(String type, String category) {
    if (type.toLowerCase() == 'expense') {
      return _expenseSubcategories[category] ?? [];
    } else if (type.toLowerCase() == 'income') {
      return _incomeSubcategories[category] ?? [];
    }
    return [];
  }

  // Expense subcategories
  static const Map<String, List<String>> _expenseSubcategories = {
    'Food & Dining': [
      'Restaurants',
      'Groceries',
      'Cafes',
      'Fast Food',
      'Food Delivery',
    ],
    'Shopping': [
      'Clothing',
      'Electronics',
      'Books',
      'Gifts',
      'Home & Garden',
    ],
    'Transportation': [
      'Fuel',
      'Public Transport',
      'Taxi/Uber',
      'Parking',
      'Vehicle Maintenance',
    ],
    'Entertainment': [
      'Movies',
      'Sports',
      'Hobbies',
      'Games',
      'Subscriptions',
    ],
    'Bills & Utilities': [
      'Electricity',
      'Water',
      'Internet',
      'Phone',
      'Rent',
    ],
    'Healthcare': [
      'Doctor',
      'Medicine',
      'Gym',
      'Insurance',
    ],
    'Education': [
      'Tuition',
      'Books',
      'Courses',
      'Supplies',
    ],
    'Personal Care': [
      'Salon',
      'Spa',
      'Cosmetics',
      'Clothing',
    ],
    'Travel': [
      'Flights',
      'Hotels',
      'Vacation',
      'Tours',
    ],
    'Other': [],
  };

  // Income subcategories
  static const Map<String, List<String>> _incomeSubcategories = {
    'Salary': [
      'Monthly Salary',
      'Bonus',
      'Overtime',
    ],
    'Business': [
      'Sales',
      'Services',
      'Commission',
    ],
    'Investments': [
      'Dividends',
      'Interest',
      'Capital Gains',
    ],
    'Gifts': [
      'Cash Gift',
      'Other',
    ],
    'Freelance': [
      'Project Payment',
      'Consulting',
    ],
    'Rental Income': [
      'Property Rent',
      'Equipment Rent',
    ],
    'Other': [],
  };
}