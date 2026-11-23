import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSidebar extends StatefulWidget {
  final String selectedItem;
  final Function(String) onItemSelected;
  final bool isCollapsed;

  const AdminSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    this.isCollapsed = false,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  final List<MenuItem> menuItems = [
    MenuItem(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
    ),
    MenuItem(
      id: 'orders',
      title: 'Orders',
      icon: Icons.shopping_bag,
    ),
    MenuItem(
      id: 'customers',
      title: 'Customers',
      icon: Icons.people,
    ),
    MenuItem(
      id: 'timeslots',
      title: 'Time Slots',
      icon: Icons.schedule,
    ),
    MenuItem(
      id: 'prepaid_packs',
      title: 'Prepaid Packs',
      icon: Icons.inventory_2,
    ),
    MenuItem(
      id: 'services',
      title: 'Services',
      icon: Icons.local_laundry_service,
    ),
    MenuItem(
      id: 'analytics',
      title: 'Analytics',
      icon: Icons.analytics,
    ),
    MenuItem(
      id: 'settings',
      title: 'Settings',
      icon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isCollapsed ? 70 : 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: widget.isCollapsed ? const EdgeInsets.all(12) : const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              border: Border(
                bottom: BorderSide(color: Color(0xFF374151)),
              ),
            ),
            child: widget.isCollapsed
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_laundry_service,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_laundry_service,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DryClean Plus',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Admin Panel',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: menuItems.map((item) {
                final isSelected = widget.selectedItem == item.id;
                return _buildMenuItem(item, isSelected);
              }).toList(),
            ),
          ),
          
          // Footer
          Container(
            padding: widget.isCollapsed ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              border: Border(
                top: BorderSide(color: Color(0xFF374151)),
              ),
            ),
            child: widget.isCollapsed
                ? CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0066FF),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF0066FF),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin User',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'admin@example.com',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item, bool isSelected) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 6 : 8, vertical: 4),
      child: InkWell(
        onTap: () => widget.onItemSelected(item.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: widget.isCollapsed 
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0066FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.isCollapsed
              ? Column(
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                    ),
                    if (isSelected)
                      const SizedBox(height: 4),
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const SizedBox(width: 6),
                    if (isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class MenuItem {
  final String id;
  final String title;
  final IconData icon;

  MenuItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}
