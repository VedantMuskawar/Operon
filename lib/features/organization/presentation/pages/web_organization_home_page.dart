import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../clients/presentation/pages/clients_management_page.dart';
import '../../../employees/presentation/pages/employee_management_page.dart';
import '../../../employees/presentation/pages/role_management_page.dart';
import 'organization_home_page.dart';

class WebOrganizationHomePage extends StatelessWidget {
  const WebOrganizationHomePage({super.key});

  static const _sectionViewIds = {
    'clients': 'clients',
    'employees': 'employees',
    'roles': 'organization-roles',
    'vendors': 'vendors',
  };

  @override
  Widget build(BuildContext context) {
    final sections = [
      ...OrganizationHomePage.defaultSections(),
      SectionData(
        label: 'Organization Home',
        emoji: '🤝',
        items: [
          SectionItem(
            emoji: '🧑‍🤝‍🧑',
            title: 'Clients',
            description: 'Manage client relationships and profiles',
            viewId: _sectionViewIds['clients'],
          ),
          SectionItem(
            emoji: '🧑‍💼',
            title: 'Employees',
            description: 'Oversee employee directories and roles',
            viewId: _sectionViewIds['employees'],
          ),
          SectionItem(
            emoji: '🛠️',
            title: 'Roles',
            description: 'Define role permissions and wage settings',
            viewId: _sectionViewIds['roles'],
          ),
          SectionItem(
            emoji: '🏪',
            title: 'Vendors',
            description: 'Track vendor partnerships and contacts',
            viewId: _sectionViewIds['vendors'],
          ),
        ],
      ),
    ];

    final customViewBuilders = <String, WidgetBuilder>{
      _sectionViewIds['clients']!: (context) => const ClientsManagementPage(),
      _sectionViewIds['employees']!: (context) => const EmployeeManagementPage(),
      _sectionViewIds['roles']!: (context) => const RoleManagementPage(),
      _sectionViewIds['vendors']!: (context) =>
          _PlaceholderPage(title: _titleFor('vendors')),
    };

    return OrganizationHomePage(
      sections: sections,
      customViewBuilders: customViewBuilders,
    );
  }

  static String _titleFor(String key) {
    switch (key) {
      case 'clients':
        return 'Clients';
      case 'employees':
        return 'Employees';
      case 'roles':
        return 'Roles';
      case 'vendors':
        return 'Vendors';
      default:
        return key;
    }
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.construction,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '$title Coming Soon',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We are building the $title experience for you.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Check back soon for updates.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
