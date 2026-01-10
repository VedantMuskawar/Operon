import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/sections/delivery_zone_selection_section.dart';
import 'package:dash_mobile/presentation/views/orders/sections/order_summary_section.dart';
import 'package:dash_mobile/presentation/views/orders/sections/product_selection_section.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:dash_mobile/presentation/widgets/standard_page_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    super.key,
    this.client,
  });

  /// Optional client record if coming from existing customer selection
  final ClientRecord? client;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  late final PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    
    if (organization == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingXL,
                  vertical: AppSpacing.itemSpacing,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.paddingSM),
                    const Expanded(
                      child: Text(
                        'Create Order',
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.iconXL + AppSpacing.paddingLG),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Please select an organization first',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final productsRepository = context.read<ProductsRepository>();
    final deliveryZonesRepository = context.read<DeliveryZonesRepository>();

    return BlocProvider(
      create: (_) => CreateOrderCubit(
        productsRepository: productsRepository,
        deliveryZonesRepository: deliveryZonesRepository,
        organizationId: organization.id,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingXL,
                  vertical: AppSpacing.itemSpacing,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: AppSpacing.paddingSM),
                    const Expanded(
                      child: Text(
                        'Create Order',
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.iconXL + AppSpacing.paddingLG),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        pageSnapping: true,
                        children: [
                          // Section 1: Product Selection
                          SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.paddingXXXL,
                              0,
                              AppSpacing.paddingXXXL,
                              MediaQuery.of(context).viewInsets.bottom + AppSpacing.sectionSpacing,
                            ),
                            child: const ProductSelectionSection(),
                          ),
                          // Section 2: Delivery Zone Selection
                          const DeliveryZoneSelectionSection(),
                          // Section 3: Summary
                          SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.paddingXXXL,
                              0,
                              AppSpacing.paddingXXXL,
                              MediaQuery.of(context).viewInsets.bottom + AppSpacing.sectionSpacing,
                            ),
                            child: OrderSummarySection(client: widget.client),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.itemSpacing),
                    StandardPageIndicator(pageCount: 3, currentIndex: _currentPage),
                    const SizedBox(height: AppSpacing.sectionSpacing),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




