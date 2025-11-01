import 'package:equatable/equatable.dart';
import '../models/product_price.dart';

abstract class ProductPriceState extends Equatable {
  const ProductPriceState();

  @override
  List<Object?> get props => [];
}

class ProductPriceInitial extends ProductPriceState {
  const ProductPriceInitial();
}

class ProductPriceLoading extends ProductPriceState {
  const ProductPriceLoading();
}

class ProductPriceLoaded extends ProductPriceState {
  final List<ProductPrice> prices;
  final String? searchQuery;

  const ProductPriceLoaded({
    required this.prices,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [prices, searchQuery];

  ProductPriceLoaded copyWith({
    List<ProductPrice>? prices,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return ProductPriceLoaded(
      prices: prices ?? this.prices,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

class ProductPriceOperating extends ProductPriceState {
  const ProductPriceOperating();
}

class ProductPriceOperationSuccess extends ProductPriceState {
  final String message;

  const ProductPriceOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductPriceError extends ProductPriceState {
  final String message;

  const ProductPriceError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductPriceEmpty extends ProductPriceState {
  final String? searchQuery;

  const ProductPriceEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

