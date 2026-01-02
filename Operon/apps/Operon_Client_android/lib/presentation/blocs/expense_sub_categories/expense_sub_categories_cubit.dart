import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'expense_sub_categories_state.dart';

class ExpenseSubCategoriesCubit extends Cubit<ExpenseSubCategoriesState> {
  ExpenseSubCategoriesCubit({
    required ExpenseSubCategoriesRepository repository,
    required String organizationId,
    required String userId,
  })  : _repository = repository,
        _organizationId = organizationId,
        _userId = userId,
        super(const ExpenseSubCategoriesState());

  final ExpenseSubCategoriesRepository _repository;
  final String _organizationId;
  final String _userId;

  String get organizationId => _organizationId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final subCategories = await _repository.fetchSubCategories(_organizationId);
      emit(state.copyWith(
        status: ViewStatus.success,
        subCategories: subCategories,
        filteredSubCategories: subCategories,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load sub-categories: $e',
      ));
    }
  }

  void search(String query) {
    if (query.trim().isEmpty) {
      emit(state.copyWith(
        searchQuery: '',
        filteredSubCategories: state.subCategories,
      ));
      return;
    }

    final queryLower = query.toLowerCase();
    final filtered = state.subCategories.where((sc) {
      return sc.name.toLowerCase().contains(queryLower) ||
          (sc.description?.toLowerCase().contains(queryLower) ?? false);
    }).toList();

    emit(state.copyWith(
      searchQuery: query,
      filteredSubCategories: filtered,
    ));
  }

  Future<void> createSubCategory(ExpenseSubCategory category) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.createSubCategory(_organizationId, category);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create sub-category: $e',
      ));
    }
  }

  Future<void> updateSubCategory(ExpenseSubCategory category) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateSubCategory(_organizationId, category);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update sub-category: $e',
      ));
    }
  }

  Future<void> deleteSubCategory(String subCategoryId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.deleteSubCategory(_organizationId, subCategoryId);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete sub-category: $e',
      ));
    }
  }

  Future<void> reorderSubCategories(Map<String, int> orderMap) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.reorderSubCategories(_organizationId, orderMap);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to reorder sub-categories: $e',
      ));
    }
  }
}

