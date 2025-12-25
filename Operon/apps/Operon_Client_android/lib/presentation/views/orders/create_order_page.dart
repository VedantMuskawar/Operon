import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/sections/delivery_zone_selection_section.dart';
import 'package:dash_mobile/presentation/views/orders/sections/order_summary_section.dart';
import 'package:dash_mobile/presentation/views/orders/sections/product_selection_section.dart';
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
      return Scaffold(
        backgroundColor: const Color(0xFF010104),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Create Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Please select an organization first',
                    style: TextStyle(color: Colors.white70),
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
        backgroundColor: const Color(0xFF010104),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Create Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
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
              color: isActive ? const Color(0xFF6F4BFF) : Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}



