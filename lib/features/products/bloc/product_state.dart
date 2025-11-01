import 'package:equatable/equatable.dart';
import '../models/product.dart';

abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

// Initial state
class ProductInitial extends ProductState {
  const ProductInitial();
}

// Loading state
class ProductLoading extends ProductState {
  const ProductLoading();
}

// Products loaded successfully
class ProductLoaded extends ProductState {
  final List<Product> products;
  final String? searchQuery;

  const ProductLoaded({
    required this.products,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [products, searchQuery];

  ProductLoaded copyWith({
    List<Product>? products,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return ProductLoaded(
      products: products ?? this.products,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

// Operation in progress (add/update/delete)
class ProductOperating extends ProductState {
  const ProductOperating();
}

// Operation successful
class ProductOperationSuccess extends ProductState {
  final String message;

  const ProductOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error state
class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}

// Empty state (no products found)
class ProductEmpty extends ProductState {
  final String? searchQuery;

  const ProductEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

