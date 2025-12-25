import 'package:dash_mobile/domain/entities/order_item.dart';
import 'package:dash_mobile/domain/entities/organization_product.dart';
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:flutter/material.dart';
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
        const Text(
          'Select Product & Trips',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        if (state.isLoadingProducts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
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
            const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              // Number of Trips Selector
              _TripQuantitySelector(
                trips: _estimatedTrips,
                onIncrement: () {
                  setState(() {
                    _estimatedTrips++;
                  });
                },
                onDecrement: () {
                  if (_estimatedTrips > 1) {
                    setState(() {
                      _estimatedTrips--;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              // Total Quantity Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${_estimatedTrips * _selectedFixedQuantity!} units',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    backgroundColor: const Color(0xFF6F4BFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Product',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          // Order Items List
          if (state.selectedItems.isNotEmpty) ...[
            const Text(
              'Product List:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...state.selectedItems.map((item) => _OrderItemTile(
                  item: item,
                  onIncrement: () => cubit.incrementItemTrips(item.productId),
                  onDecrement: () => cubit.decrementItemTrips(item.productId),
                  onRemove: () => cubit.removeProductItem(item.productId),
                )),
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
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<OrganizationProduct>(
        initialValue: selectedProduct,
        decoration: const InputDecoration(
          labelText: 'Select Product',
          labelStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF1B1B2C),
        style: const TextStyle(color: Colors.white),
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
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<int>(
        initialValue: selectedQuantity,
        decoration: const InputDecoration(
          labelText: 'Fixed Quantity Per Trip',
          labelStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF1B1B2C),
        style: const TextStyle(color: Colors.white),
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
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Decrement Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: trips > 1 ? onDecrement : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: trips > 1
                        ? const Color(0xFF1B1B2C)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: trips > 1
                          ? Colors.white24
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: trips > 1 ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Trip Count Display
            Container(
              width: 80,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: Text(
                trips.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Increment Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onIncrement,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.displayText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Trips: ',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              // Decrement
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.estimatedTrips > 1 ? onDecrement : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: item.estimatedTrips > 1
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: item.estimatedTrips > 1
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  item.estimatedTrips.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Increment
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onIncrement,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white,
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

