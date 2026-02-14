import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductsState extends BaseState {
  const ProductsState({
    super.status = ViewStatus.initial,
    this.products = const [],
    super.message,
  });

  final List<OrganizationProduct> products;
  @override
  ProductsState copyWith({
    ViewStatus? status,
    List<OrganizationProduct>? products,
    String? message,
  }) {
    return ProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      message: message ?? this.message,
    );
  }
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit({
    required ProductsRepository repository,
    required String orgId,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  })  : _repository = repository,
        _orgId = orgId,
        _canCreate = canCreate,
        _canEdit = canEdit,
        _canDelete = canDelete,
        super(const ProductsState());

  final ProductsRepository _repository;
  final String _orgId;
  final bool _canCreate;
  final bool _canEdit;
  final bool _canDelete;

  bool get canManage => _canCreate || _canEdit || _canDelete;
  bool get canCreate => _canCreate;
  bool get canEdit => _canEdit;
  bool get canDelete => _canDelete;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final products = await _repository.fetchProducts(_orgId);
      emit(state.copyWith(status: ViewStatus.success, products: products));
    } catch (_) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load products.',
        ),
      );
    }
  }

  Future<void> createProduct(OrganizationProduct product) async {
    if (!_canCreate) return;
    try {
      await _repository.createProduct(_orgId, product);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create product.',
      ));
    }
  }

  Future<void> updateProduct(OrganizationProduct product) async {
    if (!_canEdit) return;
    try {
      await _repository.updateProduct(_orgId, product);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update product.',
      ));
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (!_canDelete) return;
    try {
      await _repository.deleteProduct(_orgId, productId);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete product.',
      ));
    }
  }
}
