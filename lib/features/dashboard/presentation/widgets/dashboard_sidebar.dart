import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';

class DashboardSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final double? initialWidth;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.initialWidth,
  });

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  late double _width;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth ?? 280.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      decoration: BoxDecoration(
        // Apple-style glossy transparent background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        // Backdrop blur effect for glassmorphism
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildNavigationItems(),
              const Spacer(),
              _buildFooter(context),
              // Resize handle
              _buildResizeHandle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'OPERON',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Super Admin Portal',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems() {
    final navigationItems = [
      _NavigationItem(
        icon: Icons.dashboard,
        title: 'Dashboard',
        index: 0,
      ),
      _NavigationItem(
        icon: Icons.business,
        title: 'Organizations',
        index: 1,
      ),
      _NavigationItem(
        icon: Icons.add_business,
        title: 'Add Organization',
        index: 2,
      ),
    ];

    return Column(
      children: navigationItems.map((item) => _buildNavigationItem(item)).toList(),
    );
  }

  Widget _buildNavigationItem(_NavigationItem item) {
    final isSelected = widget.selectedIndex == item.index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onItemSelected(item.index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected 
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected 
                      ? Colors.white 
                      : Colors.white.withOpacity(0.7),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                if (isSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: const Text(
              'Super Admin',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              'Last login: Today',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.2),
                    Colors.red.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 18,
                ),
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isResizing = true;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _width = (_width + details.delta.dx).clamp(200.0, 400.0);
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isResizing = false;
        });
      },
      child: Container(
        width: double.infinity,
        height: 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final int index;

  const _NavigationItem({
    required this.icon,
    required this.title,
    required this.index,
  });
}