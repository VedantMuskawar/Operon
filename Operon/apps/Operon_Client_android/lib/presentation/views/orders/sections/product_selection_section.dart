import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/domain/entities/order_item.dart';
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductSelectionSection extends StatefulWidget {
  const ProductSelectionSection({super.key});

  @override
  State<ProductSelectionSection> createState() => _ProductSelectionSectionState();
}

class _ProductSelectionSectionState extends State<ProductSelectionSection> {
  OrganizationProduct? _selectedProduct;
  int? _selectedFixedQuantity;
  int _estimatedTrips = 1;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CreateOrderCubit>();
    final state = cubit.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Product & Trips',
          style: AppTypography.withColor(AppTypography.h3, AuthColors.textMain),
        ),
        const SizedBox(height: AppSpacing.paddingXL),
        if (state.isLoadingProducts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.paddingXL),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Product Dropdown
          _ProductDropdown(
            products: state.availableProducts,
            selectedProduct: _selectedProduct,
            onProductSelected: (product) {
              setState(() {
                _selectedProduct = product;
                _selectedFixedQuantity = null;
                _estimatedTrips = 1;
              });
            },
          ),
          if (_selectedProduct != null) ...[
            const SizedBox(height: AppSpacing.paddingLG),
            // Fixed Quantity Per Trip Dropdown
            _FixedQuantityDropdown(
              options: cubit.getFixedQuantityOptions(_selectedProduct!.id),
              selectedQuantity: _selectedFixedQuantity,
              onQuantitySelected: (quantity) {
                setState(() {
                  _selectedFixedQuantity = quantity;
                });
              },
            ),
            if (_selectedFixedQuantity != null) ...[
              const SizedBox(height: AppSpacing.paddingLG),
              // Number of Trips Selector
              _TripQuantitySelector(
                trips: _estimatedTrips,
                onIncrement: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _estimatedTrips++;
                  });
                },
                onDecrement: () {
                  if (_estimatedTrips > 1) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _estimatedTrips--;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Total Quantity Display
              Container(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
                    ),
                    Text(
                      '${_estimatedTrips * _selectedFixedQuantity!} units',
                      style: AppTypography.withColor(
                        AppTypography.withWeight(AppTypography.h4, FontWeight.w600),
                        AuthColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              // Add Product Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    cubit.addProductItem(
                      product: _selectedProduct!,
                      estimatedTrips: _estimatedTrips,
                      fixedQuantityPerTrip: _selectedFixedQuantity!,
                    );
                    // Reset form
                    setState(() {
                      _selectedProduct = null;
                      _selectedFixedQuantity = null;
                      _estimatedTrips = 1;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                    ),
                  ),
                  child: const Text(
                    'Add Product',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.paddingXXL),
          // Order Items List
          if (state.selectedItems.isNotEmpty) ...[
            Text(
              'Product List:',
              style: AppTypography.withColor(
                AppTypography.withWeight(AppTypography.h4, FontWeight.w600),
                AuthColors.textMain,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ...state.selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _OrderItemTile(
                key: ValueKey('${item.productId}_$index'),
                item: item,
                onIncrement: () {
                  HapticFeedback.selectionClick();
                  cubit.incrementItemTrips(item.productId);
                },
                onDecrement: () {
                  if (item.estimatedTrips > 1) {
                    HapticFeedback.selectionClick();
                    cubit.decrementItemTrips(item.productId);
                  }
                },
                onRemove: () => cubit.removeProductItem(item.productId),
              );
            }),
          ],
        ],
      ],
    );
  }
}

class _ProductDropdown extends StatelessWidget {
  const _ProductDropdown({
    required this.products,
    required this.selectedProduct,
    required this.onProductSelected,
  });

  final List<OrganizationProduct> products;
  final OrganizationProduct? selectedProduct;
  final ValueChanged<OrganizationProduct> onProductSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: DropdownButtonFormField<OrganizationProduct>(
        initialValue: selectedProduct,
        decoration: InputDecoration(
          labelText: 'Select Product',
          labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
        ),
        dropdownColor: AuthColors.surface,
        style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
        items: products.map((product) {
          return DropdownMenuItem<OrganizationProduct>(
            value: product,
            child: Text(product.name),
          );
        }).toList(),
        onChanged: (product) {
          if (product != null) onProductSelected(product);
        },
      ),
    );
  }
}

class _FixedQuantityDropdown extends StatelessWidget {
  const _FixedQuantityDropdown({
    required this.options,
    required this.selectedQuantity,
    required this.onQuantitySelected,
  });

  final List<int> options;
  final int? selectedQuantity;
  final ValueChanged<int> onQuantitySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: DropdownButtonFormField<int>(
        initialValue: selectedQuantity,
        decoration: InputDecoration(
          labelText: 'Fixed Quantity Per Trip',
          labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
        ),
        dropdownColor: AuthColors.surface,
        style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
        items: options.map((quantity) {
          return DropdownMenuItem<int>(
            value: quantity,
            child: Text(quantity.toString()),
          );
        }).toList(),
        onChanged: (quantity) {
          if (quantity != null) onQuantitySelected(quantity);
        },
      ),
    );
  }
}

class _TripQuantitySelector extends StatelessWidget {
  const _TripQuantitySelector({
    required this.trips,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int trips;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of Trips:',
          style: TextStyle(color: AuthColors.textSub, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(trips),
            children: [
              // Decrement Button
              Material(
                color: AuthColors.transparent,
                child: InkWell(
                  onTap: trips > 1 ? onDecrement : null,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: trips > 1
                          ? AuthColors.surface
                          : AuthColors.textMainWithOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      border: Border.all(
                        color: trips > 1
                            ? AuthColors.textMainWithOpacity(0.24)
                            : AuthColors.textMainWithOpacity(0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.remove,
                      color: trips > 1 ? AuthColors.textMain : AuthColors.textDisabled,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              // Trip Count Display
              Container(
                width: 80,
                height: 48,
                decoration: BoxDecoration(
                  color: AuthColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.24)),
                ),
                alignment: Alignment.center,
                child: Text(
                  trips.toString(),
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              // Increment Button
              Material(
                color: AuthColors.transparent,
                child: InkWell(
                  onTap: onIncrement,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AuthColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      border: Border.all(color: AuthColors.textMainWithOpacity(0.24)),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AuthColors.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final OrderItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthColors.backgroundAlt, AuthColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gapSM),
                    Text(
                      item.displayText,
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AuthColors.error),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              const Text(
                'Trips: ',
                style: TextStyle(color: AuthColors.textDisabled, fontSize: 12),
              ),
              // Decrement
              Material(
                color: AuthColors.transparent,
                child: InkWell(
                  onTap: item.estimatedTrips > 1 ? onDecrement : null,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: item.estimatedTrips > 1
                          ? AuthColors.textMain.withOpacity(0.1)
                          : AuthColors.textMain.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: item.estimatedTrips > 1
                          ? AuthColors.textMain
                          : AuthColors.textDisabled,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  item.estimatedTrips.toString(),
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              // Increment
              Material(
                color: AuthColors.transparent,
                child: InkWell(
                  onTap: onIncrement,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AuthColors.textMain.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: AuthColors.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

