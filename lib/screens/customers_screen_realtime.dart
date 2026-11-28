import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firebase_admin_service.dart';
import '../widgets/responsive.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final FirebaseAdminService _adminService = FirebaseAdminService();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    // Listen to real-time customer data
    debugPrint('CustomersScreen: Setting up customers stream');
    
    // Debug: Check what collections exist
    _adminService.debugCheckCollections();
    
    _adminService.getUsersStream().listen((customers) {
      debugPrint('CustomersScreen: Received ${customers.length} customers from Firebase');
      for (int i = 0; i < customers.length; i++) {
        debugPrint('CustomersScreen: Customer $i: ${customers[i]}');
      }
      
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoading = false;
        });
        debugPrint('CustomersScreen: Updated UI with ${customers.length} customers');
      }
    });
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final name = (customer['customerName'] as String? ?? '').toLowerCase();
      final email = (customer['email'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || 
             email.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF073B1B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredCustomers.length} Customers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  'Customers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF073B1B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredCustomers.length} Customers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: isMobile ? 'Search customers...' : 'Search customers by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Customers List
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty
                  ? _buildEmptyState()
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return _buildCustomerCard(customer);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final isActive = customer['isActive'] as bool? ?? true;
    final bool isMobile = Responsive.isMobile(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Header
          Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 20 : 24,
                backgroundColor: isActive ? const Color(0xFF073B1B) : Colors.grey,
                child: Text(
                  (customer['customerName'] as String? ?? 'Unknown')[0].toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer['customerName'] ?? 'Unknown',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer['email'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 12 : 14,
                        color: const Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.more_vert, size: 18),
                ),
                onSelected: (value) {
                  _handleCustomerAction(customer['id'], value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'view', child: Text('View Details')),
                  const PopupMenuItem(value: 'orders', child: Text('View Orders')),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Customer Stats
          Row(
            children: [
              _buildStatItem('Member Since', 
                customer['createdAt'] != null
                    ? DateFormat('MMM yyyy').format(customer['createdAt'])
                    : 'Unknown'),
              const SizedBox(width: 24),
              Builder(builder: (_) {
                final l = customer['loyalty'];
                final m = l is Map ? l : const {};
                final cnt = (m['currentCount'] as num?)?.toInt() ?? 0;
                final credit = (m['availableCredit'] as num?)?.toDouble() ?? 0.0;
                return _buildStatItem(
                  'Loyalty Card',
                  '$cnt/5 orders · £${credit.toStringAsFixed(2)} credit',
                );
              }),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No customers match your search'
                : 'No customers registered yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCustomerAction(String customerId, String action) async {
    switch (action) {
      case 'view':
        _showCustomerDetails(customerId);
        break;
      case 'orders':
        _showCustomerOrders(customerId);
        break;
    }
  }

  void _showCustomerDetails(String customerId) {
    final bool isMobile = Responsive.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: isMobile ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: Container(
          width: isMobile ? double.infinity : 600,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 12 : 0),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: const Color(0xFF047857), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Customer Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _adminService.getCustomerDetails(customerId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(child: Text('Customer not found'));
                    }
                    
                    final customer = snapshot.data!;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Personal Information Section
                          _buildSectionHeader('Personal Information', Icons.person),
                          const SizedBox(height: 12),
                          _buildDetailRow('Full Name', customer['customerName'] ?? 'Unknown'),
                          _buildDetailRow('Email', customer['email'] ?? 'N/A'),
                          _buildDetailRow('Phone', customer['phone'] ?? 'N/A'),
                          _buildDetailRow('Customer Type', customer['customerType'] ?? 'individual'),
                          if (customer['customerType'] == 'company')
                            _buildDetailRow('Company', customer['companyName'] ?? 'N/A'),
                          _buildDetailRow('Status', customer['isActive'] == true ? 'Active' : 'Inactive'),
                          _buildDetailRow('Member Since', 
                              DateFormat('MMM dd, yyyy').format(customer['createdAt'])),
                          
                          const SizedBox(height: 24),
                          
                          // Address Information Section
                          _buildSectionHeader('Address Information', Icons.location_on),
                          const SizedBox(height: 12),
                          _buildAddressSection(customer),
                          
                          const SizedBox(height: 24),
                          
                          // Additional Information Section
                          _buildSectionHeader('Additional Information', Icons.info),
                          const SizedBox(height: 12),
                          if (customer['totalOrders'] != null)
                            _buildDetailRow('Total Orders', customer['totalOrders'].toString()),
                          if (customer['totalSpent'] != null)
                            _buildDetailRow('Total Spent', '£${customer['totalSpent'].toStringAsFixed(2)}'),
                          if (customer['lastOrderDate'] != null)
                            _buildDetailRow('Last Order', 
                                DateFormat('MMM dd, yyyy').format(customer['lastOrderDate'])),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF047857), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> customer) {
    // Check for different address field structures based on actual customer data
    debugPrint('Building address section for customer: ${customer.keys}');
    
    // Check defaultAddress first (this is where address is stored based on the data structure)
    if (customer['defaultAddress'] != null) {
      final defaultAddr = customer['defaultAddress'];
      debugPrint('Found defaultAddress: $defaultAddr');
      
      if (defaultAddr is Map<String, dynamic>) {
        return _buildAddressFields(defaultAddr);
      }
    }
    
    // Check selectedAddress
    if (customer['selectedAddress'] != null) {
      final selectedAddr = customer['selectedAddress'];
      debugPrint('Found selectedAddress: $selectedAddr');
      
      if (selectedAddr is Map<String, dynamic>) {
        return _buildAddressFields(selectedAddr);
      }
    }
    
    // Check deliveryAddress
    if (customer['deliveryAddress'] != null) {
      final deliveryAddr = customer['deliveryAddress'];
      debugPrint('Found deliveryAddress: $deliveryAddr');
      
      if (deliveryAddr is Map<String, dynamic>) {
        return _buildAddressFields(deliveryAddr);
      }
    }
    
    // Check addresses array
    if (customer['addresses'] != null && customer['addresses'] is List) {
      final addresses = customer['addresses'] as List;
      debugPrint('Found addresses array with ${addresses.length} items');
      
      if (addresses.isNotEmpty) {
        final firstAddr = addresses[0];
        debugPrint('Using first address: $firstAddr');
        
        if (firstAddr is Map<String, dynamic>) {
          return _buildAddressFields(firstAddr);
        }
      }
    }
    
    // Check for direct address field
    if (customer['address'] != null) {
      final address = customer['address'];
      debugPrint('Found direct address field: $address');
      
      if (address is Map<String, dynamic>) {
        return _buildAddressFields(address);
      }
      if (address is String) {
        return _buildDetailRow('Address', address);
      }
    }
    
    return _buildDetailRow('Address', 'No address available');
  }

  Widget _buildAddressFields(Map<String, dynamic> addressData) {
    debugPrint('Building address fields from: ${addressData.keys}');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addressData['buildingName'] != null && addressData['buildingName'].toString().isNotEmpty)
          _buildDetailRow('Building Name', addressData['buildingName']),
        _buildDetailRow('Address Line 1', addressData['line1'] ?? 'N/A'),
        if (addressData['line2'] != null && addressData['line2'].toString().isNotEmpty)
          _buildDetailRow('Address Line 2', addressData['line2']),
        _buildDetailRow('City', addressData['city'] ?? 'N/A'),
        _buildDetailRow('Postal Code', addressData['postalCode'] ?? 'N/A'),
        if (addressData['isDefault'] == true)
          _buildDetailRow('Address Type', 'Default Address'),
      ],
    );
  }

  String _getOrderPrice(Map<String, dynamic> order) {
    // Debug: Show all available price fields including nested data
    debugPrint('Order price debug - Available keys: ${order.keys}');
    debugPrint('Order price debug - totalPrice: ${order['totalPrice']}');
    debugPrint('Order price debug - transactionAmount: ${order['transactionAmount']}');
    debugPrint('Order price debug - price: ${order['price']}');
    debugPrint('Order price debug - amount: ${order['amount']}');
    
    // Check for nested price data in bookingData if available
    if (order.containsKey('bookingData') && order['bookingData'] != null) {
      final bookingData = order['bookingData'] as Map<String, dynamic>?;
      if (bookingData != null) {
        debugPrint('Order price debug - bookingData keys: ${bookingData.keys}');
        debugPrint('Order price debug - bookingData totalPrice: ${bookingData['totalPrice']}');
        debugPrint('Order price debug - bookingData price: ${bookingData['price']}');
        debugPrint('Order price debug - bookingData amount: ${bookingData['amount']}');
        debugPrint('Order price debug - bookingData transactionAmount: ${bookingData['transactionAmount']}');
      }
    }
    
    // Try multiple price fields in priority order
    // Prefer transactionAmount (total with tax + fees) over totalPrice (base price)
    final transactionAmount = order['transactionAmount'] as num?;
    final bookingTransactionAmount = (order['bookingData'] as Map<String, dynamic>?)?['transactionAmount'] as num?;
    final totalPrice = order['totalPrice'] as num?;
    final price = order['price'] as num?;
    final amount = order['amount'] as num?;
    
    // Also check nested bookingData for prices
    final bookingTotalPrice = (order['bookingData'] as Map<String, dynamic>?)?['totalPrice'] as num?;
    final bookingPrice = (order['bookingData'] as Map<String, dynamic>?)?['price'] as num?;
    final bookingAmount = (order['bookingData'] as Map<String, dynamic>?)?['amount'] as num?;
    
    if (transactionAmount != null && transactionAmount > 0) {
      debugPrint('Order price debug - Using transactionAmount: $transactionAmount');
      return transactionAmount.toStringAsFixed(2);
    } else if (bookingTransactionAmount != null && bookingTransactionAmount > 0) {
      debugPrint('Order price debug - Using bookingData transactionAmount: $bookingTransactionAmount');
      return bookingTransactionAmount.toStringAsFixed(2);
    } else if (totalPrice != null && totalPrice > 0) {
      debugPrint('Order price debug - Using totalPrice: $totalPrice');
      return totalPrice.toStringAsFixed(2);
    } else if (price != null && price > 0) {
      debugPrint('Order price debug - Using price: $price');
      return price.toStringAsFixed(2);
    } else if (amount != null && amount > 0) {
      debugPrint('Order price debug - Using amount: $amount');
      return amount.toStringAsFixed(2);
    } else if (bookingTotalPrice != null && bookingTotalPrice > 0) {
      debugPrint('Order price debug - Using bookingData totalPrice: $bookingTotalPrice');
      return bookingTotalPrice.toStringAsFixed(2);
    } else if (bookingPrice != null && bookingPrice > 0) {
      debugPrint('Order price debug - Using bookingData price: $bookingPrice');
      return bookingPrice.toStringAsFixed(2);
    } else if (bookingAmount != null && bookingAmount > 0) {
      debugPrint('Order price debug - Using bookingData amount: $bookingAmount');
      return bookingAmount.toStringAsFixed(2);
    } else {
      debugPrint('Order price debug - No valid price found, using default');
      // Show what we found for debugging
      debugPrint('Order price debug - Final values: totalPrice=$totalPrice, transactionAmount=$transactionAmount, price=$price, amount=$amount');
      debugPrint('Order price debug - Booking values: bookingTotalPrice=$bookingTotalPrice, bookingPrice=$bookingPrice, bookingAmount=$bookingAmount, bookingTransactionAmount=$bookingTransactionAmount');
      return '0.00';
    }
  }

  void _showCustomerOrders(String customerId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero, // Square shape
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag, color: const Color(0xFF047857), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Customer Orders',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _adminService.getCustomerOrders(customerId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      debugPrint('CustomersScreen: Error loading orders: ${snapshot.error}');
                      return Center(child: Text('Error loading orders: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      debugPrint('CustomersScreen: No orders found for customer');
                      return const Center(child: Text('No orders found'));
                    }
                    
                    final orders = snapshot.data!;
                    debugPrint('CustomersScreen: Displaying ${orders.length} orders');
                    
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Summary
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.receipt, color: const Color(0xFF047857), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Order Summary',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Orders List
                          ...orders.asMap().entries.map((entry) {
                            final index = entry.key;
                            final order = entry.value;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Order Header
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order #${order['orderId']}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Service: ${order['serviceName']}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                'Date: ${DateFormat('MMM dd, yyyy').format(order['createdAt'])}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '£${_getOrderPrice(order)}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(order['status']).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                order['status'],
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getStatusColor(order['status']),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
