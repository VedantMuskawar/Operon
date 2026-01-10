import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/trip_wages/trip_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/trip_wages/trip_wages_state.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TripWagesPage extends StatelessWidget {
  const TripWagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/org-selection'),
                child: const Text('Select Organization'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => TripWagesCubit(
        repository: context.read<TripWagesRepository>(),
        deliveryMemoRepository: context.read<DeliveryMemoRepository>(),
        organizationId: organization.id,
      )..loadTripWages(),
      child: SectionWorkspaceLayout(
        panelTitle: 'Trip Wages',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _TripWagesContent(),
      ),
    );
  }
}

class _TripWagesContent extends StatelessWidget {
  const _TripWagesContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripWagesCubit, TripWagesState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ViewStatus.failure && state.message != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<TripWagesCubit>().loadTripWages(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip Wages',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement create trip wage dialog
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Trip Wage'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Record and manage loading/unloading wages for delivery trips.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 32),
              // TODO: Implement trip wages list UI
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Trip Wages UI - Coming Soon',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.tripWages.length} trip wage(s) loaded',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
