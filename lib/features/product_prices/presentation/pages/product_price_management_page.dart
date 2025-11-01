import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/product_price_bloc.dart';
import '../../bloc/product_price_event.dart';
import '../../bloc/product_price_state.dart';
import '../../repositories/product_price_repository.dart';
import '../../models/product_price.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../products/models/product.dart';
import '../../../addresses/repositories/address_repository.dart';
import '../../../addresses/models/address.dart';
import '../widgets/product_price_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class ProductPriceManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const ProductPriceManagementPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        
        if (organizationId == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Organization not found',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ),
          );
        }

        return BlocProvider(
          create: (context) => ProductPriceBloc(
            productPriceRepository: ProductPriceRepository(),
          )..add(LoadProductPrices(organizationId)),
          child: ProductPriceManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class ProductPriceManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const ProductPriceManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductPriceBloc, ProductPriceState>(
      listener: (context, state) {
        if (state is ProductPriceOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is ProductPriceError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Product Pricing',
              onBack: onBack,
              role: _getRoleString(userRole),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  minWidth: 800,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildContent(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleString(int userRole) {
    switch (userRole) {
      case 0:
        return 'admin';
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingLg,
          ),
          child: _buildFilterBar(context),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141618).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        '💰',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      const Text(
                        'Product Pricing',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  BlocBuilder<ProductPriceBloc, ProductPriceState>(
                    builder: (context, state) {
                      if (state is ProductPriceInitial || state is ProductPriceLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacing2xl),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductPriceError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                CustomButton(
                                  text: 'Retry',
                                  variant: CustomButtonVariant.primary,
                                  onPressed: () {
                                    context.read<ProductPriceBloc>().add(
                                      LoadProductPrices(organizationId),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductPriceEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '💰',
                                  style: TextStyle(fontSize: 64),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                const Text(
                                  'No Product Prices',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSm),
                                const Text(
                                  'Add your first product price to get started',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductPriceLoaded) {
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _loadPriceDetails(state.prices),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppTheme.spacing2xl),
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              );
                            }
                            
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading price details: ${snapshot.error}',
                                  style: const TextStyle(color: AppTheme.errorColor),
                                ),
                              );
                            }
                            
                            final data = snapshot.data!;
                            final products = data['products'] as Map<String, Product>;
                            final addresses = data['addresses'] as Map<String, Address>;
                            
                            return _buildPricesTable(context, state.prices, products, addresses);
                          },
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Future<Map<String, dynamic>> _loadPriceDetails(List<ProductPrice> prices) async {
    final productIds = prices.map((p) => p.productId).toSet().toList();
    final addressIds = prices.map((p) => p.addressId).toSet().toList();
    
    final productRepo = ProductRepository();
    final addressRepo = AddressRepository();
    
    final products = <String, Product>{};
    final addresses = <String, Address>{};
    
    for (final productId in productIds) {
      final product = await productRepo.getProductByCustomId(organizationId, productId);
      if (product != null) {
        products[productId] = product;
      }
    }
    
    for (final addressId in addressIds) {
      final address = await addressRepo.getAddressByCustomId(organizationId, addressId);
      if (address != null) {
        addresses[addressId] = address;
      }
    }
    
    return {'products': products, 'addresses': addresses};
  }

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        CustomButton(
          text: '➕ Add Product Price',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddPriceDialog(context),
        ),
      ],
    );
  }

  Widget _buildPricesTable(
    BuildContext context,
    List<ProductPrice> prices,
    Map<String, Product> products,
    Map<String, Address> addresses,
  ) {
    const double minTableWidth = 1000;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > minTableWidth 
            ? availableWidth 
            : minTableWidth;
            
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 80,
              horizontalMargin: 0,
              columnSpacing: 24,
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFF1F2937).withValues(alpha: 0.8),
              ),
              dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF374151).withValues(alpha: 0.5);
                  }
                  if (states.contains(MaterialState.hovered)) {
                    return const Color(0xFF374151).withValues(alpha: 0.3);
                  }
                  return Colors.transparent;
                },
              ),
              dividerThickness: 1,
              columns: [
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'PRODUCT',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ADDRESS',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'REGION',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'UNIT PRICE',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
              rows: prices.map((price) {
                final product = products[price.productId];
                final address = addresses[price.addressId];
                
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          product?.productName ?? price.productId,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          address?.addressName ?? price.addressId,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          address?.region ?? '—',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          '₹${price.unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: AppTheme.warningColor,
                              onPressed: () => _showEditPriceDialog(
                                context,
                                price,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXs),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppTheme.errorColor,
                              onPressed: () => _showDeleteConfirmation(
                                context,
                                price,
                                product?.productName ?? 'Unknown',
                                address?.addressName ?? 'Unknown',
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.errorColor
                                    .withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showAddPriceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProductPriceFormDialog(
        organizationId: organizationId,
        onSubmit: (price) {
          Navigator.of(dialogContext).pop();
          _submitPrice(context, price);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditPriceDialog(
    BuildContext context,
    ProductPrice price,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProductPriceFormDialog(
        organizationId: organizationId,
        price: price,
        onSubmit: (updatedPrice) {
          Navigator.of(dialogContext).pop();
          _updatePrice(context, price, updatedPrice);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ProductPrice price,
    String productName,
    String addressName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Product Price',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete price for "$productName" at "$addressName"?',
          style: const TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: CustomButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          CustomButton(
            text: 'Delete',
            variant: CustomButtonVariant.danger,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deletePrice(context, price);
            },
          ),
        ],
      ),
    );
  }

  void _submitPrice(
    BuildContext context,
    ProductPrice price,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<ProductPriceBloc>().add(
      AddProductPrice(
        organizationId: organizationId,
        price: price,
        userId: userId,
      ),
    );
  }

  void _updatePrice(
    BuildContext context,
    ProductPrice oldPrice,
    ProductPrice newPrice,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<ProductPriceBloc>().add(
      UpdateProductPrice(
        organizationId: organizationId,
        priceId: oldPrice.id!,
        price: newPrice,
        userId: userId,
      ),
    );
  }

  void _deletePrice(
    BuildContext context,
    ProductPrice price,
  ) {
    context.read<ProductPriceBloc>().add(
      DeleteProductPrice(
        organizationId: organizationId,
        priceId: price.id!,
      ),
    );
  }
}

