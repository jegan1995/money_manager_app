class Categories {
  // Expense Categories with Subcategories
  static const Map<String, List<String>> expenseCategories = {
    'Food & Dining': [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snacks',
      'Coffee/Tea',
      'Restaurant',
      'Fast Food',
      'Groceries',
    ],
    'Transportation': [
      'Fuel',
      'Public Transport',
      'Taxi/Auto',
      'Parking',
      'Vehicle Maintenance',
      'Toll',
    ],
    'Shopping': [
      'Clothing',
      'Footwear',
      'Electronics',
      'Accessories',
      'Home Decor',
      'Gifts',
    ],
    'Entertainment': [
      'Movies',
      'Games',
      'Sports',
      'Music',
      'Books',
      'Hobbies',
    ],
    'Bills & Utilities': [
      'Electricity',
      'Water',
      'Gas',
      'Internet',
      'Mobile',
      'TV/Streaming',
      'Rent',
      'Maintenance',
    ],
    'Healthcare': [
      'Doctor Visit',
      'Medicines',
      'Lab Tests',
      'Health Insurance',
      'Gym/Fitness',
    ],
    'Education': [
      'Tuition Fees',
      'Books',
      'Courses',
      'Stationery',
    ],
    'Personal Care': [
      'Salon/Spa',
      'Cosmetics',
      'Toiletries',
    ],
    'Travel': [
      'Flight',
      'Hotel',
      'Vacation',
      'Sightseeing',
    ],
    'Others': [
      'Miscellaneous',
    ],
  };

  // Income Categories with Subcategories
  static const Map<String, List<String>> incomeCategories = {
    'Salary': [
      'Monthly Salary',
      'Bonus',
      'Overtime',
      'Commission',
    ],
    'Business': [
      'Sales',
      'Services',
      'Consulting',
      'Freelance',
    ],
    'Investments': [
      'Stocks',
      'Mutual Funds',
      'Dividends',
      'Interest',
      'Rental Income',
    ],
    'Gifts': [
      'Cash Gift',
      'Gift Received',
    ],
    'Others': [
      'Miscellaneous',
      'Refund',
    ],
  };

  // Get main categories based on type
  static List<String> getMainCategories(String type) {
    if (type == 'expense') {
      return expenseCategories.keys.toList();
    } else if (type == 'income') {
      return incomeCategories.keys.toList();
    }
    return [];
  }

  // Get subcategories for a category
  static List<String> getSubcategories(String type, String category) {
    if (type == 'expense') {
      return expenseCategories[category] ?? [];
    } else if (type == 'income') {
      return incomeCategories[category] ?? [];
    }
    return [];
  }
}
