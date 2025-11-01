import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../bloc/android_product_bloc.dart';
import '../../repositories/android_product_repository.dart';
import '../../models/product.dart';
import '../widgets/android_product_form_dialog.dart';

class AndroidProductManagementPage extends StatelessWidget {
  final String organizationId;
  final String userId;

  const AndroidProductManagementPage({
    super.key,
    required this.organizationId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AndroidProductBloc(
        repository: AndroidProductRepository(),
      )..add(AndroidLoadProducts(organizationId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AndroidProductBloc, AndroidProductState>(
          listener: (context, state) {
            if (state is AndroidProductOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else if (state is AndroidProductError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: BlocBuilder<AndroidProductBloc, AndroidProductState>(
            builder: (context, state) {
              if (state is AndroidProductLoading || state is AndroidProductInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AndroidProductError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(state.message, style: const TextStyle(color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AndroidProductBloc>().add(
                            AndroidLoadProducts(organizationId),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidProductEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondaryColor),
                      const SizedBox(height: 16),
                      const Text('No products found', style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddProductDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidProductLoaded) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Products (${state.products.length})',
                            style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddProductDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AndroidConfig.defaultPadding),
                        itemCount: state.products.length,
                        itemBuilder: (context, index) {
                          final product = state.products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.surfaceColor,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                              ),
                              title: Text(
                                product.productName,
                                style: const TextStyle(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${product.productId}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  if (product.description != null)
                                    Text(product.description!, style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${product.unitPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: product.isActive
                                              ? AppTheme.successColor.withOpacity(0.2)
                                              : AppTheme.errorColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          product.status,
                                          style: TextStyle(
                                            color: product.isActive ? AppTheme.successColor : AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                color: AppTheme.surfaceColor,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showEditProductDialog(context, product),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showDeleteConfirmDialog(context, product),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddProductDialog(context),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidProductFormDialog(
        onSubmit: (product) {
          context.read<AndroidProductBloc>().add(
            AndroidAddProduct(
              organizationId: organizationId,
              product: product,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidProductFormDialog(
        product: product,
        onSubmit: (product) {
          context.read<AndroidProductBloc>().add(
            AndroidUpdateProduct(
              organizationId: organizationId,
              productId: product.id!,
              product: product,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Product', style: TextStyle(color: AppTheme.textPrimaryColor)),
        content: Text(
          'Are you sure you want to delete ${product.productName}?',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AndroidProductBloc>().add(
                AndroidDeleteProduct(
                  organizationId: organizationId,
                  productId: product.id!,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

