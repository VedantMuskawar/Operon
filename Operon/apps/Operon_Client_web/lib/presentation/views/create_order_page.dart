import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/orders/sections/delivery_zone_selection_section.dart';
import 'package:dash_web/presentation/views/orders/sections/order_summary_section.dart';
import 'package:dash_web/presentation/views/orders/sections/product_selection_section.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    super.key,
    this.client,
  });

  final Client? client;

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
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
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
      return PageWorkspaceLayout(
        title: 'Create Order',
        currentIndex: -1,
        onNavTap: (index) {
          if (index >= 0) {
            context.go('/home?section=$index');
          }
        },
        onBack: () => context.pop(),
        child: const Center(
          child: Text(
            'Please select an organization first',
            style: TextStyle(color: AuthColors.textSub),
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
      child: PageWorkspaceLayout(
        title: 'Create Order',
        currentIndex: -1,
        onNavTap: (index) {
          if (index >= 0) {
            context.go('/home?section=$index');
          }
        },
        onBack: () => context.pop(),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: [
                        // Section 1: Product Selection
                        const SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(32, 0, 32, 0),
                          child: ProductSelectionSection(),
                        ),
                        // Section 2: Delivery Zone Selection
                        const DeliveryZoneSelectionSection(),
                        // Section 3: Summary
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                          child: OrderSummarySection(client: widget.client),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PageIndicator(pageCount: 3, currentIndex: _currentPage),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AuthColors.primary : AuthColors.textMainWithOpacity(0.24),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}
