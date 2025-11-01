import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/android_product_repository.dart';
import '../models/product.dart';

abstract class AndroidProductEvent extends Equatable {
  const AndroidProductEvent();
  @override
  List<Object?> get props => [];
}

class AndroidLoadProducts extends AndroidProductEvent {
  final String organizationId;
  const AndroidLoadProducts(this.organizationId);
  @override
  List<Object?> get props => [organizationId];
}

class AndroidAddProduct extends AndroidProductEvent {
  final String organizationId;
  final Product product;
  final String userId;
  const AndroidAddProduct({
    required this.organizationId,
    required this.product,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, product, userId];
}

class AndroidUpdateProduct extends AndroidProductEvent {
  final String organizationId;
  final String productId;
  final Product product;
  final String userId;
  const AndroidUpdateProduct({
    required this.organizationId,
    required this.productId,
    required this.product,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, productId, product, userId];
}

class AndroidDeleteProduct extends AndroidProductEvent {
  final String organizationId;
  final String productId;
  const AndroidDeleteProduct({
    required this.organizationId,
    required this.productId,
  });
  @override
  List<Object?> get props => [organizationId, productId];
}

abstract class AndroidProductState extends Equatable {
  const AndroidProductState();
  @override
  List<Object?> get props => [];
}

class AndroidProductInitial extends AndroidProductState {}
class AndroidProductLoading extends AndroidProductState {}
class AndroidProductLoaded extends AndroidProductState {
  final List<Product> products;
  const AndroidProductLoaded({required this.products});
  @override
  List<Object?> get props => [products];
}
class AndroidProductOperating extends AndroidProductState {}
class AndroidProductOperationSuccess extends AndroidProductState {
  final String message;
  const AndroidProductOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidProductError extends AndroidProductState {
  final String message;
  const AndroidProductError(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidProductEmpty extends AndroidProductState {}

class AndroidProductBloc extends Bloc<AndroidProductEvent, AndroidProductState> {
  final AndroidProductRepository _repository;

  AndroidProductBloc({required AndroidProductRepository repository})
      : _repository = repository,
        super(AndroidProductInitial()) {
    on<AndroidLoadProducts>(_onLoadProducts);
    on<AndroidAddProduct>(_onAddProduct);
    on<AndroidUpdateProduct>(_onUpdateProduct);
    on<AndroidDeleteProduct>(_onDeleteProduct);
  }

  Future<void> _onLoadProducts(
    AndroidLoadProducts event,
    Emitter<AndroidProductState> emit,
  ) async {
    try {
      emit(AndroidProductLoading());
      await emit.forEach(
        _repository.getProductsStream(event.organizationId),
        onData: (List<Product> products) {
          print('Products stream received ${products.length} products');
          final state = products.isEmpty 
              ? AndroidProductEmpty() 
              : AndroidProductLoaded(products: products);
          print('Emitting product state: ${state.runtimeType}');
          emit(state);
          return state;
        },
        onError: (error, stackTrace) {
          print('Error in products stream: $error');
          final errorState = AndroidProductError('Failed to load products: $error');
          emit(errorState);
          return errorState;
        },
      );
    } catch (e) {
      emit(AndroidProductError('Failed to load products: $e'));
    }
  }

  Future<void> _onAddProduct(
    AndroidAddProduct event,
    Emitter<AndroidProductState> emit,
  ) async {
    try {
      emit(AndroidProductOperating());
      await _repository.addProduct(event.organizationId, event.product, event.userId);
      emit(AndroidProductOperationSuccess('Product added successfully'));
    } catch (e) {
      emit(AndroidProductError('Failed to add product: $e'));
    }
  }

  Future<void> _onUpdateProduct(
    AndroidUpdateProduct event,
    Emitter<AndroidProductState> emit,
  ) async {
    try {
      emit(AndroidProductOperating());
      await _repository.updateProduct(
        event.organizationId,
        event.productId,
        event.product,
        event.userId,
      );
      emit(AndroidProductOperationSuccess('Product updated successfully'));
    } catch (e) {
      emit(AndroidProductError('Failed to update product: $e'));
    }
  }

  Future<void> _onDeleteProduct(
    AndroidDeleteProduct event,
    Emitter<AndroidProductState> emit,
  ) async {
    try {
      emit(AndroidProductOperating());
      await _repository.deleteProduct(event.organizationId, event.productId);
      emit(AndroidProductOperationSuccess('Product deleted successfully'));
    } catch (e) {
      emit(AndroidProductError('Failed to delete product: $e'));
    }
  }
}

