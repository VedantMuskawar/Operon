import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class ExpenseSubCategoriesState extends BaseState {
  const ExpenseSubCategoriesState({
    super.status = ViewStatus.initial,
    this.subCategories = const [],
    this.filteredSubCategories = const [],
    this.searchQuery = '',
    super.message,
  });

  final List<ExpenseSubCategory> subCategories;
  final List<ExpenseSubCategory> filteredSubCategories;
  final String searchQuery;
  bool get isSearching => searchQuery.isNotEmpty;

  @override
  ExpenseSubCategoriesState copyWith({
    ViewStatus? status,
    List<ExpenseSubCategory>? subCategories,
    List<ExpenseSubCategory>? filteredSubCategories,
    String? searchQuery,
    String? message,
  }) {
    return ExpenseSubCategoriesState(
      status: status ?? this.status,
      subCategories: subCategories ?? this.subCategories,
      filteredSubCategories:
          filteredSubCategories ?? this.filteredSubCategories,
      searchQuery: searchQuery ?? this.searchQuery,
      message: message ?? this.message,
    );
  }
}
