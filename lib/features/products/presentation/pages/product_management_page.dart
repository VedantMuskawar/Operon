import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/product_bloc.dart';
import '../../bloc/product_event.dart';
import '../../bloc/product_state.dart';
import '../../repositories/product_repository.dart';
import '../../models/product.dart';
import '../widgets/product_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class ProductManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const ProductManagementPage({
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
          create: (context) => ProductBloc(
            productRepository: ProductRepository(),
          )..add(LoadProducts(organizationId)),
          child: ProductManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class ProductManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const ProductManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is ProductError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Products',
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
                        '📦',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      const Text(
                        'Products',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  BlocBuilder<ProductBloc, ProductState>(
                    builder: (context, state) {
                      if (state is ProductInitial || state is ProductLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacing2xl),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductError) {
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
                                    context.read<ProductBloc>().add(
                                      LoadProducts(organizationId),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '📦',
                                  style: TextStyle(fontSize: 64),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.searchQuery != null
                                      ? 'No Products Found'
                                      : 'No Products',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSm),
                                Text(
                                  state.searchQuery != null
                                      ? 'No products match your search criteria'
                                      : 'Add your first product to get started',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingLg),
                                if (state.searchQuery != null)
                                  CustomButton(
                                    text: 'Clear Search',
                                    variant: CustomButtonVariant.outline,
                                    onPressed: () {
                                      context.read<ProductBloc>().add(
                                        const ResetProductSearch(),
                                      );
                                      context.read<ProductBloc>().add(
                                        LoadProducts(organizationId),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is ProductLoaded) {
                        return _buildProductsTable(context, state.products);
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

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        CustomButton(
          text: '➕ Add Product',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddProductDialog(context),
        ),
        const Spacer(),
        SizedBox(
          width: 300,
          child: BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              return CustomTextField(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, size: 18),
                variant: CustomTextFieldVariant.search,
                onChanged: (query) {
                  if (query.isEmpty) {
                    context.read<ProductBloc>().add(
                      const ResetProductSearch(),
                    );
                    context.read<ProductBloc>().add(
                      LoadProducts(organizationId),
                    );
                  } else {
                    context.read<ProductBloc>().add(
                      SearchProducts(
                        organizationId: organizationId,
                        query: query,
                      ),
                    );
                  }
                },
                suffixIcon: state is ProductLoaded && 
                            state.searchQuery != null &&
                            state.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          context.read<ProductBloc>().add(
                            const ResetProductSearch(),
                          );
                          context.read<ProductBloc>().add(
                            LoadProducts(organizationId),
                          );
                        },
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(
    BuildContext context,
    List<Product> products,
  ) {
    const double minTableWidth = 900;
    
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
                      'PRODUCT ID',
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
                      'PRODUCT NAME',
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
                      'DESCRIPTION',
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
                      'BASE PRICE',
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
                      'STATUS',
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
              rows: products.map((product) {
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          product.productId,
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
                          product.productName,
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
                          product.description ?? '—',
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
                          '₹${product.unitPrice.toStringAsFixed(2)}',
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
                        child: _buildStatusBadge(product.status),
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
                              onPressed: () => _showEditProductDialog(
                                context,
                                product,
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
                                product,
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

  Widget _buildStatusBadge(String status) {
    Color color;
    if (status == 'Active') {
      color = AppTheme.successColor;
    } else {
      color = AppTheme.textTertiaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProductFormDialog(
        onSubmit: (product) {
          Navigator.of(dialogContext).pop();
          _submitProduct(context, product);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditProductDialog(
    BuildContext context,
    Product product,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProductFormDialog(
        product: product,
        onSubmit: (updatedProduct) {
          Navigator.of(dialogContext).pop();
          _updateProduct(context, product, updatedProduct);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Product product,
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
          'Delete Product',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${product.productName}"?',
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
              _deleteProduct(context, product);
            },
          ),
        ],
      ),
    );
  }

  void _submitProduct(
    BuildContext context,
    Product product,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<ProductBloc>().add(
      AddProduct(
        organizationId: organizationId,
        product: product,
        userId: userId,
      ),
    );
  }

  void _updateProduct(
    BuildContext context,
    Product oldProduct,
    Product newProduct,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<ProductBloc>().add(
      UpdateProduct(
        organizationId: organizationId,
        productId: oldProduct.id!,
        product: newProduct,
        userId: userId,
      ),
    );
  }

  void _deleteProduct(
    BuildContext context,
    Product product,
  ) {
    context.read<ProductBloc>().add(
      DeleteProduct(
        organizationId: organizationId,
        productId: product.id!,
      ),
    );
  }
}

