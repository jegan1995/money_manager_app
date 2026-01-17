// Predefined subcategories for each category
class Subcategories {
  // Expense Subcategories
  static const Map<String, List<String>> expenseSubcategories = {
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

  // Income Subcategories
  static const Map<String, List<String>> incomeSubcategories = {
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

  // Get subcategories for a category
  static List<String> getSubcategories(String type, String category) {
    if (type == 'expense') {
      return expenseSubcategories[category] ?? ['Miscellaneous'];
    } else {
      return incomeSubcategories[category] ?? ['Miscellaneous'];
    }
  }
}