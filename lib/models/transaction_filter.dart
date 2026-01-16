enum FilterType { all, income, expense }
enum DateFilter { all, today, last7days, last30days, custom }

class TransactionFilter {
  final FilterType type;
  final String? category;
  final DateFilter dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;

  TransactionFilter({
    this.type = FilterType.all,
    this.category,
    this.dateFilter = DateFilter.all,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
  });

  TransactionFilter copyWith({
    FilterType? type,
    String? category,
    DateFilter? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      category: category ?? this.category,
      dateFilter: dateFilter ?? this.dateFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters {
    return type != FilterType.all ||
        category != null ||
        dateFilter != DateFilter.all ||
        searchQuery.isNotEmpty;
  }
}
