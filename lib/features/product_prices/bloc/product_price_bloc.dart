import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'product_price_event.dart';
import 'product_price_state.dart';
import '../repositories/product_price_repository.dart';
import '../models/product_price.dart';

class ProductPriceBloc extends Bloc<ProductPriceEvent, ProductPriceState> {
  final ProductPriceRepository _productPriceRepository;

  ProductPriceBloc({required ProductPriceRepository productPriceRepository})
      : _productPriceRepository = productPriceRepository,
        super(const ProductPriceInitial()) {
    on<LoadProductPrices>(_onLoadProductPrices);
    on<AddProductPrice>(_onAddProductPrice);
    on<UpdateProductPrice>(_onUpdateProductPrice);
    on<DeleteProductPrice>(_onDeleteProductPrice);
    on<ResetProductPriceSearch>(_onResetSearch);
    on<RefreshProductPrices>(_onRefreshProductPrices);
  }

  Future<void> _onLoadProductPrices(
    LoadProductPrices event,
    Emitter<ProductPriceState> emit,
  ) async {
    try {
      emit(const ProductPriceLoading());

      await emit.forEach(
        _productPriceRepository.getProductPricesStream(event.organizationId),
        onData: (List<ProductPrice> prices) {
          if (prices.isEmpty) {
            return const ProductPriceEmpty();
          }
          return ProductPriceLoaded(prices: prices);
        },
        onError: (error, stackTrace) {
          return ProductPriceError('Failed to load product prices: $error');
        },
      );
    } catch (e) {
      emit(ProductPriceError('Failed to load product prices: $e'));
    }
  }

  Future<void> _onAddProductPrice(
    AddProductPrice event,
    Emitter<ProductPriceState> emit,
  ) async {
    try {
      emit(const ProductPriceOperating());

      await _productPriceRepository.addProductPrice(
        event.organizationId,
        event.price,
        event.userId,
      );

      emit(const ProductPriceOperationSuccess('Product price added successfully'));
    } catch (e) {
      emit(ProductPriceError('Failed to add product price: $e'));
    }
  }

  Future<void> _onUpdateProductPrice(
    UpdateProductPrice event,
    Emitter<ProductPriceState> emit,
  ) async {
    try {
      emit(const ProductPriceOperating());

      await _productPriceRepository.updateProductPrice(
        event.organizationId,
        event.priceId,
        event.price,
        event.userId,
      );

      emit(const ProductPriceOperationSuccess('Product price updated successfully'));
    } catch (e) {
      emit(ProductPriceError('Failed to update product price: $e'));
    }
  }

  Future<void> _onDeleteProductPrice(
    DeleteProductPrice event,
    Emitter<ProductPriceState> emit,
  ) async {
    try {
      emit(const ProductPriceOperating());

      await _productPriceRepository.deleteProductPrice(
        event.organizationId,
        event.priceId,
      );

      emit(const ProductPriceOperationSuccess('Product price deleted successfully'));
    } catch (e) {
      emit(ProductPriceError('Failed to delete product price: $e'));
    }
  }

  void _onResetSearch(
    ResetProductPriceSearch event,
    Emitter<ProductPriceState> emit,
  ) {
    if (state is ProductPriceLoaded) {
      final currentState = state as ProductPriceLoaded;
      emit(currentState.copyWith(searchQueryReset: () => null));
    }
  }

  Future<void> _onRefreshProductPrices(
    RefreshProductPrices event,
    Emitter<ProductPriceState> emit,
  ) async {
    try {
      emit(const ProductPriceLoading());

      final prices = await _productPriceRepository.getProductPrices(
        event.organizationId,
      );

      if (prices.isEmpty) {
        emit(const ProductPriceEmpty());
      } else {
        emit(ProductPriceLoaded(prices: prices));
      }
    } catch (e) {
      emit(ProductPriceError('Failed to refresh product prices: $e'));
    }
  }
}

