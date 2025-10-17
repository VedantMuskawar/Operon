import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../organization/bloc/organization_bloc.dart';
import '../../../organization/presentation/widgets/add_organization_form.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/metrics_cards.dart';
import '../widgets/organizations_list.dart';
import '../widgets/subscription_analytics_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardHomePage(),
    const OrganizationsListPage(),
    const AddOrganizationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OrganizationRepository>(
          create: (context) => OrganizationRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<OrganizationBloc>(
            create: (context) => OrganizationBloc(
              organizationRepository: context.read<OrganizationRepository>(),
            ),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Row(
              children: [
                DashboardSidebar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      const DashboardHeader(),
                      Expanded(
                        child: _pages[_selectedIndex],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrganizationBloc, OrganizationState>(
      builder: (context, state) {
        final organizations = state is OrganizationsLoaded ? state.organizations : <dynamic>[];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const MetricsCards(),
              const SizedBox(height: 32),
              if (organizations.isNotEmpty) ...[
                SubscriptionAnalyticsChart(
                  organizations: organizations.cast(),
                ),
                const SizedBox(height: 32),
              ],
              const Text(
                'Recent Organizations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400, // Fixed height for organizations list
                child: OrganizationsList(
                  showRecentOnly: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrganizationsListPage extends StatelessWidget {
  const OrganizationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organizations',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: OrganizationsList(),
          ),
        ],
      ),
    );
  }
}

class AddOrganizationPage extends StatelessWidget {
  const AddOrganizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AddOrganizationForm();
  }
}
