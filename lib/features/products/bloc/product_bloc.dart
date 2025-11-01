import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'product_event.dart';
import 'product_state.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;

  ProductBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(const ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<SearchProducts>(_onSearchProducts);
    on<ResetProductSearch>(_onResetSearch);
    on<RefreshProducts>(_onRefreshProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductLoading());

      await emit.forEach(
        _productRepository.getProductsStream(event.organizationId),
        onData: (List<Product> products) {
          if (products.isEmpty) {
            return const ProductEmpty();
          }
          return ProductLoaded(products: products);
        },
        onError: (error, stackTrace) {
          return ProductError('Failed to load products: $error');
        },
      );
    } catch (e) {
      emit(ProductError('Failed to load products: $e'));
    }
  }

  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductOperating());

      await _productRepository.addProduct(
        event.organizationId,
        event.product,
        event.userId,
      );

      emit(const ProductOperationSuccess('Product added successfully'));
    } catch (e) {
      emit(ProductError('Failed to add product: $e'));
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductOperating());

      await _productRepository.updateProduct(
        event.organizationId,
        event.productId,
        event.product,
        event.userId,
      );

      emit(const ProductOperationSuccess('Product updated successfully'));
    } catch (e) {
      emit(ProductError('Failed to update product: $e'));
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductOperating());

      await _productRepository.deleteProduct(
        event.organizationId,
        event.productId,
      );

      emit(const ProductOperationSuccess('Product deleted successfully'));
    } catch (e) {
      emit(ProductError('Failed to delete product: $e'));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductLoading());

      await emit.forEach(
        _productRepository.searchProducts(
          event.organizationId,
          event.query,
        ),
        onData: (List<Product> products) {
          if (products.isEmpty && event.query.isNotEmpty) {
            return ProductEmpty(searchQuery: event.query);
          } else if (products.isEmpty) {
            return const ProductEmpty();
          }
          return ProductLoaded(products: products, searchQuery: event.query);
        },
        onError: (error, stackTrace) {
          return ProductError('Failed to search products: $error');
        },
      );
    } catch (e) {
      emit(ProductError('Failed to search products: $e'));
    }
  }

  void _onResetSearch(
    ResetProductSearch event,
    Emitter<ProductState> emit,
  ) {
    if (state is ProductLoaded) {
      final currentState = state as ProductLoaded;
      emit(currentState.copyWith(searchQueryReset: () => null));
    }
  }

  Future<void> _onRefreshProducts(
    RefreshProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      emit(const ProductLoading());

      final products = await _productRepository.getProducts(
        event.organizationId,
      );

      if (products.isEmpty) {
        emit(const ProductEmpty());
      } else {
        emit(ProductLoaded(products: products));
      }
    } catch (e) {
      emit(ProductError('Failed to refresh products: $e'));
    }
  }
}

