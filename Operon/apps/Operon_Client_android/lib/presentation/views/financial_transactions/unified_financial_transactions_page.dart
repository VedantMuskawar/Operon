import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_mobile/presentation/views/financial_transactions/financial_transactions_analytics_view.dart';
import 'package:dash_mobile/presentation/views/financial_transactions/financial_transactions_list_view.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UnifiedFinancialTransactionsPage extends StatefulWidget {
  const UnifiedFinancialTransactionsPage({super.key});

  @override
  State<UnifiedFinancialTransactionsPage> createState() =>
      _UnifiedFinancialTransactionsPageState();
}

class _UnifiedFinancialTransactionsPageState
    extends State<UnifiedFinancialTransactionsPage> {
  late final PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(_onPageChanged);
    // Load data on init
    context.read<UnifiedFinancialTransactionsCubit>().load();
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

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AuthColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: '*Transactions',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
                        children: const [
                          FinancialTransactionsListView(),
                          FinancialTransactionsAnalyticsView(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CompactPageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: 16),
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
              color: isActive
                  ? AuthColors.primary
                  : AuthColors.textMainWithOpacity(0.25),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        },
      ),
    );
  }
}
