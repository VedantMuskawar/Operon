import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';

class HomeOverviewView extends StatelessWidget {
  const HomeOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OrganizationContextCubit>().state.role;
    final tiles = <Widget>[
      const _OverviewTile(
        icon: Icons.people_outline,
        label: 'Clients',
        route: '/clients',
      ),
      const _OverviewTile(
        icon: Icons.group_outlined,
        label: 'Employees',
        route: '/employees',
      ),
    ];
    if (role?.canAccessPage('zonesCity') == true ||
        role?.canAccessPage('zonesRegion') == true ||
        role?.canAccessPage('zonesPrice') == true) {
      tiles.add(const _OverviewTile(
        icon: Icons.location_city_outlined,
        label: 'Zones',
        route: '/zones',
      ));
    }
    if (role?.canAccessPage('vehicles') == true) {
      tiles.add(const _OverviewTile(
        icon: Icons.local_shipping_outlined,
        label: 'Vehicles',
        route: '/vehicles',
      ));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: tiles,
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

