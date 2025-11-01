import 'package:equatable/equatable.dart';
import '../models/product_price.dart';

abstract class ProductPriceEvent extends Equatable {
  const ProductPriceEvent();

  @override
  List<Object?> get props => [];
}

class LoadProductPrices extends ProductPriceEvent {
  final String organizationId;

  const LoadProductPrices(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

class AddProductPrice extends ProductPriceEvent {
  final String organizationId;
  final ProductPrice price;
  final String userId;

  const AddProductPrice({
    required this.organizationId,
    required this.price,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, price, userId];
}

class UpdateProductPrice extends ProductPriceEvent {
  final String organizationId;
  final String priceId;
  final ProductPrice price;
  final String userId;

  const UpdateProductPrice({
    required this.organizationId,
    required this.priceId,
    required this.price,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, priceId, price, userId];
}

class DeleteProductPrice extends ProductPriceEvent {
  final String organizationId;
  final String priceId;

  const DeleteProductPrice({
    required this.organizationId,
    required this.priceId,
  });

  @override
  List<Object?> get props => [organizationId, priceId];
}

class ResetProductPriceSearch extends ProductPriceEvent {
  const ResetProductPriceSearch();
}

class RefreshProductPrices extends ProductPriceEvent {
  final String organizationId;

  const RefreshProductPrices(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

