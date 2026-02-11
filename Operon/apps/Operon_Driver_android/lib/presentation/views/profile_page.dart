import 'package:core_ui/core_ui.dart';
import 'package:operon_driver_android/data/repositories/users_repository.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AuthColors.textMain,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF Pro Display',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ProfileView(
            user: authState.userProfile,
            organization: organization,
            fetchUserName: (authState.userProfile?.id != null && organization?.id != null)
                ? () async {
                    debugPrint('[ProfilePage] Starting fetchUserName');
                    debugPrint('[ProfilePage] orgId: ${organization!.id}');
                    debugPrint('[ProfilePage] userId: ${authState.userProfile!.id}');
                    debugPrint('[ProfilePage] phoneNumber: ${authState.userProfile!.phoneNumber}');
                    debugPrint('[ProfilePage] user.displayName: ${authState.userProfile?.displayName}');
                    
                    try {
                      final orgUser = await context.read<UsersRepository>().fetchCurrentUser(
                        orgId: organization.id,
                        userId: authState.userProfile!.id,
                        phoneNumber: authState.userProfile!.phoneNumber,
                      );
                      
                      debugPrint('[ProfilePage] fetchCurrentUser returned: ${orgUser != null}');
                      debugPrint('[ProfilePage] orgUser?.name: ${orgUser?.name}');
                      debugPrint('[ProfilePage] orgUser?.id: ${orgUser?.id}');
                      debugPrint('[ProfilePage] orgUser?.phone: ${orgUser?.phone}');
                      
                      // Return name from organization user, or fallback to user displayName
                      final name = orgUser?.name;
                      if (name != null && name.isNotEmpty && name != 'Unnamed') {
                        debugPrint('[ProfilePage] Returning orgUser.name: $name');
                        return name;
                      }
                      // Fallback to user's displayName from auth
                      debugPrint('[ProfilePage] Name is null/empty/Unnamed, falling back to displayName: ${authState.userProfile?.displayName}');
                      return authState.userProfile?.displayName;
                    } catch (e, stackTrace) {
                      debugPrint('[ProfilePage] Error fetching user name: $e');
                      debugPrint('[ProfilePage] Stack trace: $stackTrace');
                      // On error, return user's displayName as fallback
                      debugPrint('[ProfilePage] Returning fallback displayName: ${authState.userProfile?.displayName}');
                      return authState.userProfile?.displayName;
                    }
                  }
                : null,
            onChangeOrg: () {
              context.go('/org-selection');
            },
            onLogout: () {
              context.read<AuthBloc>().add(const AuthReset());
              context.go('/login');
            },
            // Driver app doesn't expose admin pages (users/permissions) right now.
            onOpenUsers: null,
          ),
        ),
      ),
    );
  }
}
