import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/home_overview_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/pending_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/schedule_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_map_view.dart';
import 'package:dash_mobile/presentation/widgets/home_workspace_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentIndex = widget.initialIndex;
  List<int> _allowedSections = const [0];

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
      _ensureIndexAllowed();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = context.watch<OrganizationContextCubit>().state.role;
    final allowed = computeHomeSections(role);
    if (!listEquals(allowed, _allowedSections)) {
      setState(() {
        _allowedSections = allowed;
      });
    }
    _ensureIndexAllowed();
  }

  static const _sections = [
    HomeOverviewView(),
    PendingOrdersView(),
    ScheduleOrdersView(),
    OrdersMapView(),
    _AnalyticsPlaceholder(),
  ];

  static const _sectionTitles = [
    '',
    '',
    '',
    'Orders Map',
    '',
  ];

  void _ensureIndexAllowed() {
    if (!_allowedSections.contains(_currentIndex)) {
      setState(() {
        _currentIndex = _allowedSections.first;
      });
    }
  }

  void _handleNavTap(int index) {
    if (!_allowedSections.contains(index)) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return HomeWorkspaceLayout(
      panelTitle: _sectionTitles[_currentIndex],
      currentIndex: _currentIndex,
      onNavTap: _handleNavTap,
      allowedSections: _allowedSections,
      child: _sections[_currentIndex],
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Analytics coming soon',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

