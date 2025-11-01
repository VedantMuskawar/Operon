import 'package:equatable/equatable.dart';
import '../models/product.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

// Load products for an organization
class LoadProducts extends ProductEvent {
  final String organizationId;

  const LoadProducts(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Add a new product
class AddProduct extends ProductEvent {
  final String organizationId;
  final Product product;
  final String userId;

  const AddProduct({
    required this.organizationId,
    required this.product,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, product, userId];
}

// Update an existing product
class UpdateProduct extends ProductEvent {
  final String organizationId;
  final String productId;
  final Product product;
  final String userId;

  const UpdateProduct({
    required this.organizationId,
    required this.productId,
    required this.product,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, productId, product, userId];
}

// Delete a product
class DeleteProduct extends ProductEvent {
  final String organizationId;
  final String productId;

  const DeleteProduct({
    required this.organizationId,
    required this.productId,
  });

  @override
  List<Object?> get props => [organizationId, productId];
}

// Search products
class SearchProducts extends ProductEvent {
  final String organizationId;
  final String query;

  const SearchProducts({
    required this.organizationId,
    required this.query,
  });

  @override
  List<Object?> get props => [organizationId, query];
}

// Reset search
class ResetProductSearch extends ProductEvent {
  const ResetProductSearch();
}

// Refresh products
class RefreshProducts extends ProductEvent {
  final String organizationId;

  const RefreshProducts(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

