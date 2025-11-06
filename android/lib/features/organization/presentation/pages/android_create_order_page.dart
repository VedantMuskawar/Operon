import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../../../../core/app_theme.dart';
import '../../../products/models/product.dart';
import '../../../products/repositories/android_product_repository.dart';
import '../../../location_pricing/models/location_pricing.dart';
import '../../../location_pricing/repositories/android_location_pricing_repository.dart';
import '../../models/order.dart';
import '../../models/client.dart';
import '../../repositories/android_order_repository.dart';
import '../../repositories/android_client_repository.dart';

class AndroidCreateOrderPage extends StatefulWidget {
  final String organizationId;
  final String? clientId; // Optional - if creating from client page
  final Order? existingOrder; // Optional - if editing existing order

  const AndroidCreateOrderPage({
    super.key,
    required this.organizationId,
    this.clientId,
    this.existingOrder,
  });

  @override
  State<AndroidCreateOrderPage> createState() => _AndroidCreateOrderPageState();
}

class _AndroidCreateOrderPageState extends State<AndroidCreateOrderPage> {
  late final PageController _pageController;
  final _formKey = GlobalKey<FormState>();
  late int _currentStep; // Start at step 0 if no client

  // Repositories
  final AndroidProductRepository _productRepository = AndroidProductRepository();
  final AndroidLocationPricingRepository _locationRepository = AndroidLocationPricingRepository();
  final AndroidOrderRepository _orderRepository = AndroidOrderRepository();
  final AndroidClientRepository _clientRepository = AndroidClientRepository();

  // Step 1: Products
  List<Product> _allProducts = [];
  String? _selectedProductId; // Single product selection
  int _quantity = 0; // Quantity for selected product
  int _trips = 1; // Number of trips
  bool _productsLoading = false;

  // Step 2: Location & Address
  List<LocationPricing> _allLocations = [];
  List<String> _regions = [];
  List<String> _cities = [];
  String? _selectedRegion;
  String? _selectedCity;
  LocationPricing? _currentLocationPricing;
  
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _newRegionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  
  bool _locationLoading = false;
  bool _isNewRegion = false;
  String? _selectedPaymentType; // Payment type selection

  // Step 0: Client Selection (if clientId not provided)
  List<Client> _allClients = [];
  String? _selectedClientId;
  bool _clientsLoading = false;

  // Step 3: Review
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  // Client info
  String? _clientName;
  String? _clientPhone;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.clientId == null ? 0 : 0; // Start at step 0 (products if client provided, client selection if not)
    _pageController = PageController(initialPage: _currentStep);
    _selectedPaymentType = PaymentType.payOnDelivery; // Default payment type
    _loadProducts();
    _loadLocations();
    if (widget.existingOrder != null) {
      // Pre-fill form with existing order data
      _selectedClientId = widget.existingOrder!.clientId;
      _selectedRegion = widget.existingOrder!.region;
      _selectedCity = widget.existingOrder!.city;
      _trips = widget.existingOrder!.trips;
      _selectedPaymentType = widget.existingOrder!.paymentType;
      if (widget.existingOrder!.items.isNotEmpty) {
        _selectedProductId = widget.existingOrder!.items.first.productId;
        _quantity = widget.existingOrder!.items.first.quantity;
        _quantityController.text = _quantity.toString();
      }
      if (widget.existingOrder!.items.isNotEmpty) {
        final firstItem = widget.existingOrder!.items.first;
        _unitPriceController.text = firstItem.unitPrice.toStringAsFixed(2);
      }
      if (widget.existingOrder!.notes != null) {
        _notesController.text = widget.existingOrder!.notes!;
      }
      _loadClientInfo();
    } else if (widget.clientId != null) {
      _selectedClientId = widget.clientId;
      _loadClientInfo();
    } else {
      _loadClients();
    }
  }

  Future<void> _loadClients() async {
    setState(() {
      _clientsLoading = true;
    });

    try {
      final clients = await _clientRepository.getClients(widget.organizationId);
      setState(() {
        _allClients = clients;
        _clientsLoading = false;
      });
    } catch (e) {
      setState(() {
        _clientsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _unitPriceController.dispose();
    _newRegionController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClientInfo() async {
    final clientIdToLoad = _selectedClientId ?? widget.clientId;
    if (clientIdToLoad == null) return;
    try {
      final client = await _clientRepository.getClient(
        widget.organizationId,
        clientIdToLoad,
      );
      if (client != null && mounted) {
        setState(() {
          _selectedClientId = clientIdToLoad;
          _clientName = client.name;
          _clientPhone = client.phoneNumber;
        });
      }
    } catch (e) {
      // Silently fail - client info is optional
    }
  }

  int _getMaxStep() {
    return widget.clientId == null ? 3 : 2; // Client(0), Product(1), Address(2), Confirm(3) OR Product(0), Address(1), Confirm(2)
  }

  Future<void> _loadProducts() async {
    setState(() {
      _productsLoading = true;
    });

    try {
      final products = await _productRepository.getProducts(widget.organizationId);
      setState(() {
        _allProducts = products;
        _productsLoading = false;
      });
    } catch (e) {
      setState(() {
        _productsLoading = false;
      });
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await _locationRepository.getLocationPricings(widget.organizationId);
      setState(() {
        _allLocations = locations;
        _regions = locations.map((l) => l.locationName).toSet().toList()..sort();
        _cities = locations.map((l) => l.city).toSet().toList()..sort();
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onRegionChanged(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedCity = null;
      _currentLocationPricing = null;
      _unitPriceController.clear();
      
      if (region != null) {
        _cities = _allLocations
            .where((l) => l.locationName == region)
            .map((l) => l.city)
            .toSet()
            .toList()
          ..sort();
      } else {
        _cities = _allLocations.map((l) => l.city).toSet().toList()..sort();
      }
    });
  }

  void _onCityChanged(String? city) async {
    setState(() {
      _selectedCity = city;
      _locationLoading = true;
    });

    if (_selectedRegion != null && city != null) {
      try {
        final pricing = await _locationRepository.getLocationPricingByCity(
          widget.organizationId,
          city,
          _selectedRegion!,
        );

        setState(() {
          _currentLocationPricing = pricing;
          if (pricing != null) {
            _unitPriceController.text = pricing.unitPrice.toStringAsFixed(2);
          } else {
            _unitPriceController.clear();
          }
          _locationLoading = false;
        });
      } catch (e) {
        setState(() {
          _locationLoading = false;
        });
      }
    } else {
      setState(() {
        _locationLoading = false;
      });
    }
  }

  double _calculateSubtotal() {
    if (_selectedProductId == null || _quantity == 0 || _unitPriceController.text.isEmpty) return 0.0;
    
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    
    return _quantity * unitPrice * _trips;
  }

  bool _canProceedToStep2() {
    return _selectedProductId != null && _quantity > 0;
  }

  bool _canProceedToStep3() {
    if (_isNewRegion) {
      // For new region, require region name, existing city selection, and unit price
      return _newRegionController.text.trim().isNotEmpty &&
          _selectedCity != null &&
          _unitPriceController.text.isNotEmpty &&
          (double.tryParse(_unitPriceController.text) ?? 0) > 0;
    } else {
      return _selectedRegion != null &&
          _selectedCity != null &&
          _unitPriceController.text.isNotEmpty &&
          (double.tryParse(_unitPriceController.text) ?? 0) > 0;
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      // Determine final region and city (from existing or new inputs)
      final finalRegion = _isNewRegion ? _newRegionController.text.trim() : _selectedRegion!;
      final finalCity = _isNewRegion ? _selectedCity! : _selectedCity!;
      
      // Update or create location pricing (always save, especially for new regions)
      final unitPrice = double.parse(_unitPriceController.text);
      final locationId = await _locationRepository.createOrUpdateLocationPricing(
        widget.organizationId,
        finalRegion,
        finalCity,
        unitPrice,
        userId,
      );

      // Get updated location pricing for reference
      final locationPricing = await _locationRepository.getLocationPricingByCity(
        widget.organizationId,
        finalCity,
        finalRegion,
      );

      // Build order items - single product only
      final orderItems = <OrderItem>[];
      if (_selectedProductId != null && _quantity > 0) {
        final product = _allProducts.firstWhere((p) => p.productId == _selectedProductId);
        orderItems.add(OrderItem(
          productId: product.productId,
          productName: product.productName,
          quantity: _quantity,
          unitPrice: unitPrice,
          totalPrice: _quantity * unitPrice * _trips,
        ));
      }

      final subtotal = _calculateSubtotal();

      // Generate order ID
      final orderId = _generateOrderId();

      final order = widget.existingOrder != null
          ? widget.existingOrder!.copyWith(
              items: orderItems,
              region: finalRegion,
              city: finalCity,
              locationId: locationPricing?.id,
              subtotal: subtotal,
              totalAmount: subtotal,
              trips: _trips,
              paymentType: _selectedPaymentType ?? PaymentType.payOnDelivery,
              notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            )
          : Order(
              orderId: orderId,
              organizationId: widget.organizationId,
              clientId: _selectedClientId ?? widget.clientId ?? '',
              status: OrderStatus.pending,
              items: orderItems,
              deliveryAddress: OrderDeliveryAddress(
                street: '',
                city: finalCity,
                state: '',
                zipCode: '',
                country: '',
              ),
              region: finalRegion,
              city: finalCity,
              locationId: locationPricing?.id,
              subtotal: subtotal,
              totalAmount: subtotal,
              trips: _trips,
              paymentType: _selectedPaymentType ?? PaymentType.payOnDelivery,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              createdBy: userId,
              updatedBy: userId,
              notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            );

      if (widget.existingOrder != null) {
        // Update existing order
        await _orderRepository.updateOrder(
          widget.organizationId,
          widget.existingOrder!.orderId,
          order,
          userId,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order updated successfully')),
          );
        }
      } else {
        // Create new order
        await _orderRepository.createOrder(widget.organizationId, order, userId);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order created successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating order: $e')),
        );
      }
    }
  }

  String _generateOrderId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingOrder != null
              ? 'Edit Order${_currentStep > 0 ? ' (${_currentStep + 1}/${widget.clientId == null ? 4 : 3})' : ''}'
              : 'Create Order${_currentStep > 0 ? ' (${_currentStep + 1}/${widget.clientId == null ? 4 : 3})' : ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: widget.clientId == null
                  ? Row(
                      children: [
                        _buildProgressStep(0, 'Client', _currentStep >= 0),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 1
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        _buildProgressStep(1, 'Product', _currentStep >= 1),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 2
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        _buildProgressStep(2, 'Address', _currentStep >= 2),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 3
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        _buildProgressStep(3, 'Confirm', _currentStep >= 3),
                      ],
                    )
                  : Row(
                      children: [
                        _buildProgressStep(0, 'Product', _currentStep >= 0),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 1
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        _buildProgressStep(1, 'Address', _currentStep >= 1),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 2
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        _buildProgressStep(2, 'Confirm', _currentStep >= 2),
                      ],
                    ),
            ),
            
            // Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: widget.clientId == null
                    ? [
                        _buildClientSelectionStep(),
                        _buildProductsStep(),
                        _buildLocationStep(),
                        _buildReviewStep(),
                      ]
                    : [
                        _buildProductsStep(),
                        _buildLocationStep(),
                        _buildReviewStep(),
                      ],
              ),
            ),
            
            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(color: AppTheme.borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.borderColor),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentStep < _getMaxStep()
                          ? (_currentStep == 0 && widget.clientId == null && _selectedClientId == null) ||
                                  (_currentStep == (widget.clientId == null ? 1 : 0) && !_canProceedToStep2()) ||
                                  (_currentStep == (widget.clientId == null ? 2 : 1) && !_canProceedToStep3())
                              ? null
                              : () {
                                  if (_currentStep == 0 && widget.clientId == null) {
                                    // Load client info for selected client
                                    _loadClientInfo();
                                  }
                                  setState(() {
                                    _currentStep++;
                                  });
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                          : _isSubmitting
                              ? null
                              : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _currentStep < _getMaxStep()
                                  ? 'Next'
                                  : widget.existingOrder != null
                                      ? 'Update Order'
                                      : 'Create Order',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textSecondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildClientSelectionStep() {
    if (_clientsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Clients Available',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add clients before creating orders',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allClients.length,
      itemBuilder: (context, index) {
        final client = _allClients[index];
        final isSelected = _selectedClientId == client.clientId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: RadioListTile<String>(
            value: client.clientId,
            groupValue: _selectedClientId,
            onChanged: (value) {
              setState(() {
                _selectedClientId = value;
                _loadClientInfo();
              });
            },
            title: Text(
              client.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            subtitle: Text(
              client.phoneNumber,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsStep() {
    if (_productsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Products Available',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Select Product Header Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const Text(
            'Select Product',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        
        // Trips Selector (Above tiles)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'No. of Trips:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (_trips > 1) {
                          setState(() {
                            _trips--;
                          });
                        }
                      },
                      color: AppTheme.primaryColor,
                    ),
                    Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: Text(
                        '$_trips',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() {
                          _trips++;
                        });
                      },
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Product Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: _allProducts.length,
            itemBuilder: (context, index) {
              final product = _allProducts[index];
              final isSelected = _selectedProductId == product.productId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedProductId == product.productId) {
                      _selectedProductId = null;
                      _quantity = 0;
                    } else {
                      _selectedProductId = product.productId;
                      _quantity = 1;
                      _quantityController.text = '1';
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Product Icon in Circle
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                              : AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          size: 40,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Product Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          product.productName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Quantity Input (Below tiles) - Number Input Field
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.format_list_numbered,
                  color: AppTheme.textSecondaryColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quantity:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    onChanged: (value) {
                      final quantity = int.tryParse(value) ?? 0;
                      setState(() {
                        _quantity = quantity;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Select Address Header - Modern Design
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Toggle between Existing and New Region - Enhanced Design
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isNewRegion = false;
                        _selectedRegion = null;
                        _selectedCity = null;
                        _currentLocationPricing = null;
                        _unitPriceController.clear();
                        _newRegionController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isNewRegion
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        border: Border.all(
                          color: !_isNewRegion
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: !_isNewRegion ? 2 : 0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_searching,
                            size: 18,
                            color: !_isNewRegion
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Existing',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_isNewRegion
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isNewRegion = true;
                        _selectedRegion = null;
                        _selectedCity = null;
                        _currentLocationPricing = null;
                        _unitPriceController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isNewRegion
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border.all(
                          color: _isNewRegion
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: _isNewRegion ? 2 : 0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_location_alt,
                            size: 18,
                            color: _isNewRegion
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'New Region',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isNewRegion
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Existing Region/City Selection
          if (!_isNewRegion) ...[
            // Region Dropdown
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: InputDecoration(
                labelText: 'Region *',
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select Region'),
                ),
                ..._regions.map((region) {
                  return DropdownMenuItem(
                    value: region,
                    child: Text(region),
                  );
                }),
              ],
              onChanged: _onRegionChanged,
              validator: (value) {
                if (!_isNewRegion && (value == null || value.isEmpty)) {
                  return 'Please select a region';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // City Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: InputDecoration(
                labelText: 'City *',
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_city),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select City'),
                ),
                ..._cities.map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }),
              ],
              onChanged: _onCityChanged,
              validator: (value) {
                if (!_isNewRegion && (value == null || value.isEmpty)) {
                  return 'Please select a city';
                }
                return null;
              },
            ),
          ] else ...[
            // New Region Input - User must select existing city
            TextFormField(
              controller: _newRegionController,
              decoration: InputDecoration(
                labelText: 'New Region Name *',
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
                helperText: 'Enter a new region name',
              ),
              validator: (value) {
                if (_isNewRegion && (value == null || value.trim().isEmpty)) {
                  return 'Please enter a region name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // City Selection for New Region (must select from existing cities)
            DropdownButtonFormField<String>(
              value: _selectedCity,
              decoration: InputDecoration(
                labelText: 'City *',
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_city),
                helperText: 'Select an existing city for this new region',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select City'),
                ),
                ...() {
                  final cities = _allLocations.map((l) => l.city).toSet().toList();
                  cities.sort();
                  return cities.map((city) => DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  ));
                }(),
              ],
              onChanged: (city) {
                setState(() {
                  _selectedCity = city;
                  _currentLocationPricing = null;
                  _unitPriceController.clear();
                });
              },
              validator: (value) {
                if (_isNewRegion && (value == null || value.isEmpty)) {
                  return 'Please select a city';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),

          // Unit Price (always required)
          if (_locationLoading)
            const Center(child: CircularProgressIndicator())
          else
            TextFormField(
              controller: _unitPriceController,
              decoration: InputDecoration(
                labelText: 'Unit Price (₹) *',
                hintText: _isNewRegion
                    ? 'Enter unit price for new region'
                    : _currentLocationPricing != null
                        ? 'Price from location pricing'
                        : 'Enter unit price',
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.currency_rupee),
                suffixIcon: _currentLocationPricing != null && !_isNewRegion
                    ? Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryColor,
                      )
                    : null,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Unit price is required';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
          if (_currentLocationPricing != null && !_isNewRegion)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Text(
                'Price loaded from location pricing. Edit to update.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (_isNewRegion)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Text(
                'New region pricing will be saved to location pricing.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final subtotal = _calculateSubtotal();
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final selectedProduct = _selectedProductId != null
        ? _allProducts.firstWhere((p) => p.productId == _selectedProductId)
        : null;
    final finalRegion = _isNewRegion ? _newRegionController.text.trim() : _selectedRegion;
    final finalCity = _selectedCity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedProduct != null) ...[
                  _buildSummaryRow('Product', selectedProduct.productName),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Quantity', '$_quantity units'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Trips', '$_trips'),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Unit Price', '₹${unitPrice.toStringAsFixed(2)}'),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        '₹${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Location Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (finalRegion != null && finalRegion.isNotEmpty)
                  _buildSummaryRow('Region', finalRegion),
                if (finalRegion != null && finalRegion.isNotEmpty)
                  const SizedBox(height: 8),
                if (finalCity != null && finalCity.isNotEmpty)
                  _buildSummaryRow('City', finalCity),
                const SizedBox(height: 8),
                _buildSummaryRow('Unit Price', '₹${unitPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildSummaryRow('Payment Type', PaymentType.getDisplayName(_selectedPaymentType ?? PaymentType.payOnDelivery)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Payment Type Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Type *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentOption(
                        PaymentType.payOnDelivery,
                        'Pay on Delivery',
                        Icons.delivery_dining,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaymentOption(
                        PaymentType.payLater,
                        'Pay Later',
                        Icons.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaymentOption(
                  PaymentType.advance,
                  'Advance',
                  Icons.payment,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Any additional information...',
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.note),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String paymentType, String label, IconData icon, {bool fullWidth = false}) {
    final isSelected = _selectedPaymentType == paymentType;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentType = paymentType;
        });
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.1) 
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor 
                : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? AppTheme.primaryColor 
                  : AppTheme.textSecondaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? AppTheme.primaryColor 
                      : AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }
}

