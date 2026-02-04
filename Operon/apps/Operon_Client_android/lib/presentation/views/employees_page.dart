import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/recently_viewed_employees_service.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/employees_page/employee_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/utils/debouncer.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  late final ScrollController _scrollController;
  late final Debouncer _searchDebouncer;
  double _currentPage = 0;
  final bool _isLoadingMore = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 300));
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(_onPageChanged);
    _scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    final newPage = _pageController.page ?? 0;
    final roundedPage = newPage.round();
    if (roundedPage != _currentPage.round()) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more if needed - for now just a placeholder
      // Future pagination support can be added here
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Employees',
      ),
      body: SafeArea(
        child: BlocListener<EmployeesCubit, EmployeesState>(
          listener: (context, state) {
            if (state.status == ViewStatus.failure && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message!)),
              );
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        children: [
                          _EmployeesListView(
                            scrollController: _scrollController,
                            isLoadingMore: _isLoadingMore,
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onClearSearch: _clearSearch,
                          ),
                          const EmployeeAnalyticsPage(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    _CompactPageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: AppSpacing.paddingLG),
                  ],
                ),
              ),
              QuickNavBar(
                currentIndex: -1, // -1 means no selection when on this page
                onTap: (value) => context.go('/home', extra: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _EmployeesListView extends StatefulWidget {
  const _EmployeesListView({
    required this.scrollController,
    required this.isLoadingMore,
    required this.searchController,
    required this.searchQuery,
    required this.onClearSearch,
  });

  final ScrollController scrollController;
  final bool isLoadingMore;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;

  @override
  State<_EmployeesListView> createState() => _EmployeesListViewState();
}

class _EmployeesListViewState extends State<_EmployeesListView> {
  List<String> _recentlyViewedIds = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
  }

  Future<void> _loadRecentlyViewed() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId != null) {
      final ids = await RecentlyViewedEmployeesService.getRecentlyViewedIds(organizationId);
      if (mounted) {
        setState(() {
          _recentlyViewedIds = ids;
          _isLoadingRecent = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingRecent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesCubit, EmployeesState>(
      buildWhen: (previous, current) {
        // Only rebuild when relevant state changes
        return previous.employees != current.employees ||
            previous.status != current.status;
      },
      builder: (context, state) {
        final allEmployees = state.employees;
        
        // When not searching, show recently viewed employees (up to 10)
        final displayEmployees = widget.searchQuery.isEmpty
            ? _getRecentlyViewedEmployees(allEmployees)
            : allEmployees;
        
        final filteredEmployees = _getFilteredEmployees(displayEmployees, widget.searchQuery);

        // Error state
        if (state.status == ViewStatus.failure) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.paddingLG,
              AppSpacing.paddingLG,
              AppSpacing.paddingLG,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.paddingLG,
            ),
            child: Column(
              children: [
                _buildSearchBar(context, state),
                const SizedBox(height: AppSpacing.paddingXXL),
                ErrorStateWidget(
                  message: state.message ?? 'Failed to load employees',
                  errorType: ErrorType.network,
                  onRetry: () {
                    context.read<EmployeesCubit>().load();
                  },
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.paddingLG,
                AppSpacing.paddingLG,
                AppSpacing.paddingLG,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.paddingLG,
              ),
                  sliver: SliverToBoxAdapter(
                child: _buildSearchBar(context, state),
              ),
            ),
            if (state.status == ViewStatus.loading && allEmployees.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (widget.searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _SearchResultsCard(
                  state: state,
                  employees: filteredEmployees,
                  onClear: widget.onClearSearch,
                  searchQuery: widget.searchQuery,
                ),
              )
            else if (filteredEmployees.isEmpty && state.status != ViewStatus.loading)
              const SliverFillRemaining(
                child: _EmptyEmployeesState(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                sliver: AnimationLimiter(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= filteredEmployees.length) {
                          return widget.isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.paddingLG),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: _EmployeeTile(
                                employee: filteredEmployees[index],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredEmployees.length + (widget.isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<OrganizationEmployee> _getRecentlyViewedEmployees(List<OrganizationEmployee> allEmployees) {
    return RecentlyViewedEmployeesService.getRecentlyViewedEmployees(
      allEmployees: allEmployees,
      recentlyViewedIds: _recentlyViewedIds,
      getId: (employee) => employee.id,
    );
  }

  static final _filteredCache = <String, List<OrganizationEmployee>>{};
  static String? _lastEmployeesHash;
  static String? _lastSearchQuery;

  List<OrganizationEmployee> _getFilteredEmployees(
    List<OrganizationEmployee> employees,
    String query,
  ) {
    // Cache key based on employees hash and search query
    final employeesHash = '${employees.length}_${employees.hashCode}';
    final cacheKey = '${employeesHash}_$query';

    // Check if we can reuse cached result
    if (_lastEmployeesHash == employeesHash &&
        _lastSearchQuery == query &&
        _filteredCache.containsKey(cacheKey)) {
      return _filteredCache[cacheKey]!;
    }

    // Invalidate cache if employees list changed
    if (_lastEmployeesHash != employeesHash) {
      _filteredCache.clear();
    }

    // Calculate filtered list
    final filtered = query.isEmpty
        ? employees
        : employees
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

    // Cache result
    _filteredCache[cacheKey] = filtered;
    _lastEmployeesHash = employeesHash;
    _lastSearchQuery = query;

    return filtered;
  }

  Widget _buildSearchBar(BuildContext context, EmployeesState state) {
    return StandardSearchBar(
      controller: widget.searchController,
      hintText: 'Search employees by name',
      onChanged: (value) {
        // The parent handles search state
      },
      onClear: widget.onClearSearch,
    );
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload recently viewed when dependencies change (e.g., when coming back from detail page)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentlyViewed();
    });
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.state,
    required this.employees,
    required this.onClear,
    required this.searchQuery,
  });

  final EmployeesState state;
  final List<OrganizationEmployee> employees;
  final VoidCallback onClear;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          if (state.status == ViewStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXL),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (employees.isEmpty)
            _EmptySearchState(query: searchQuery)
          else
            ...employees.map((employee) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                  child: _EmployeeTile(
                    employee: employee,
                  ),
                )),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
  });

  final OrganizationEmployee employee;

  static final _colorCache = <String, Color>{};
  static final _initialsCache = <String, String>{};
  static final _subtitleCache = <String, String>{};

  Color _getEmployeeColor() {
    final cacheKey = employee.id;
    if (_colorCache.containsKey(cacheKey)) {
      return _colorCache[cacheKey]!;
    }

    final hash = employee.primaryJobRoleTitle.hashCode;
    final colors = [
      AuthColors.primary,
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
    ];
    final color = colors[hash.abs() % colors.length];
    _colorCache[cacheKey] = color;
    return color;
  }

  String _getInitials(String name) {
    if (_initialsCache.containsKey(name)) {
      return _initialsCache[name]!;
    }

    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase());
    _initialsCache[name] = initials;
    return initials;
  }

  String _getRoleInitials(String roleTitle) {
    if (roleTitle.isEmpty) return '?';
    // Take first 2 characters of role title, or first character if single letter
    return roleTitle.length >= 2
        ? roleTitle.substring(0, 2).toUpperCase()
        : roleTitle[0].toUpperCase();
  }

  String _getSubtitle() {
    final cacheKey = '${employee.id}_${employee.primaryJobRoleTitle}_${employee.currentBalance}_${employee.wage.baseAmount}_${employee.wage.type.name}';
    if (_subtitleCache.containsKey(cacheKey)) {
      return _subtitleCache[cacheKey]!;
    }

    final subtitleParts = <String>[];
    subtitleParts.add(employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle);
    subtitleParts.add('₹${employee.currentBalance.toStringAsFixed(2)}');
    if (employee.wage.baseAmount != null) {
      subtitleParts.add('Salary: ₹${employee.wage.baseAmount!.toStringAsFixed(2)}/${_getSalaryTypeLabelFromWage(employee.wage.type)}');
    }
    final subtitle = subtitleParts.join(' • ');
    _subtitleCache[cacheKey] = subtitle;
    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final employeeColor = _getEmployeeColor();
    final subtitle = _getSubtitle();
    final balanceDifference = employee.currentBalance - employee.openingBalance;
    final isPositive = balanceDifference >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      child: DataList(
        title: employee.name,
        subtitle: subtitle.isNotEmpty ? subtitle : null,
        leading: DataListAvatar(
          initial: _getRoleInitials(employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle),
          radius: 28,
          statusRingColor: employeeColor,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (balanceDifference != 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapSM, vertical: AppSpacing.paddingXS / 2),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AuthColors.success.withOpacity(0.15)
                        : AuthColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: isPositive ? AuthColors.success : AuthColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '₹${balanceDifference.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isPositive ? AuthColors.success : AuthColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        onTap: () => context.pushNamed('employee-detail', extra: employee),
      ),
    );
  }

  String _getSalaryTypeLabelFromWage(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'month';
      case WageType.perTrip:
        return 'trip';
      case WageType.perBatch:
        return 'batch';
      case WageType.perHour:
        return 'hour';
      case WageType.perKm:
        return 'km';
      case WageType.commission:
        return 'commission';
      case WageType.hybrid:
        return 'hybrid';
    }
  }
}

class _EmptyEmployeesState extends StatelessWidget {
  const _EmptyEmployeesState();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.badge_outlined,
      title: 'No employees yet',
      message: 'No employees to display.',
      iconColor: AuthColors.primary,
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingXXXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'No employees match "$query"',
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _CompactPageIndicator extends StatelessWidget {
  const _CompactPageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 24 : 6,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        },
      ),
    );
  }
}

