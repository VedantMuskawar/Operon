import 'package:core_models/core_models.dart';
import 'expense_sub_categories_data_source.dart';

class ExpenseSubCategoriesRepository {
  ExpenseSubCategoriesRepository({
    required ExpenseSubCategoriesDataSource dataSource,
  }) : _dataSource = dataSource;

  final ExpenseSubCategoriesDataSource _dataSource;

  Future<List<ExpenseSubCategory>> fetchSubCategories(String organizationId) {
    return _dataSource.fetchSubCategories(organizationId);
  }

  Stream<List<ExpenseSubCategory>> watchSubCategories(String organizationId) {
    return _dataSource.watchSubCategories(organizationId);
  }

  Future<ExpenseSubCategory?> getSubCategory(
    String organizationId,
    String subCategoryId,
  ) {
    return _dataSource.getSubCategory(organizationId, subCategoryId);
  }

  Future<String> createSubCategory(
    String organizationId,
    ExpenseSubCategory category,
  ) {
    return _dataSource.createSubCategory(organizationId, category);
  }

  Future<void> updateSubCategory(
    String organizationId,
    ExpenseSubCategory category,
  ) {
    return _dataSource.updateSubCategory(organizationId, category);
  }

  Future<void> deleteSubCategory(
    String organizationId,
    String subCategoryId,
  ) {
    return _dataSource.deleteSubCategory(organizationId, subCategoryId);
  }

  Future<void> reorderSubCategories(
    String organizationId,
    Map<String, int> orderMap,
  ) {
    return _dataSource.reorderSubCategories(organizationId, orderMap);
  }
}

