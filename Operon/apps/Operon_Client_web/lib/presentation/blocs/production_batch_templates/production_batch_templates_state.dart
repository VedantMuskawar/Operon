import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class ProductionBatchTemplatesState extends BaseState {
  const ProductionBatchTemplatesState({
    super.status = ViewStatus.initial,
    this.templates = const [],
    super.message,
  });

  final List<ProductionBatchTemplate> templates;

  @override
  ProductionBatchTemplatesState copyWith({
    ViewStatus? status,
    List<ProductionBatchTemplate>? templates,
    String? message,
  }) {
    return ProductionBatchTemplatesState(
      status: status ?? this.status,
      templates: templates ?? this.templates,
      message: message,
    );
  }
}

