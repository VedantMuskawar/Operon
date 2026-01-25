import 'package:dash_web/data/repositories/organization_locations_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/organization_locations/organization_locations_cubit.dart';
import 'package:dash_web/presentation/views/organization_locations_page_content.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OrganizationLocationsPage extends StatelessWidget {
  const OrganizationLocationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<OrganizationLocationsCubit>(
          create: (context) => OrganizationLocationsCubit(
            repository: context.read<OrganizationLocationsRepository>(),
            organizationId: organization.id,
          )..load(),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Locations & Geofences',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const OrganizationLocationsPageContent(),
      ),
    );
  }
}
