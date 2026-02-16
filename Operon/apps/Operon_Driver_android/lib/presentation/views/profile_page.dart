import 'package:core_ui/core_ui.dart';
import 'package:operon_driver_android/data/repositories/users_repository.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/presentation/blocs/app_update/app_update_bloc.dart';
import 'package:operon_driver_android/presentation/blocs/app_update/app_update_event.dart';
import 'package:operon_driver_android/presentation/blocs/app_update/app_update_state.dart';
import 'package:operon_driver_android/presentation/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final versionLabel = info == null
                  ? null
                  : '${info.version} (${info.buildNumber})';

              return BlocListener<AppUpdateBloc, AppUpdateState>(
                listener: (context, state) {
                  if (state is AppUpdateCheckingState) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Checking for updates...'),
                        ),
                      );
                  } else if (state is AppUpdateUnavailableState) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('You are on the latest version.'),
                        ),
                      );
                  } else if (state is AppUpdateErrorState) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Update check failed: ${state.message}'),
                        ),
                      );
                  } else if (state is AppUpdateAvailableState) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Update available.'),
                        ),
                      );
                  }
                },
                child: ProfileView(
                  user: authState.userProfile,
                  organization: organization,
                  appVersion: versionLabel,
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

                            final name = orgUser?.name;
                            if (name != null && name.isNotEmpty && name != 'Unnamed') {
                              debugPrint('[ProfilePage] Returning orgUser.name: $name');
                              return name;
                            }
                            debugPrint('[ProfilePage] Name is null/empty/Unnamed, falling back to displayName: ${authState.userProfile?.displayName}');
                            return authState.userProfile?.displayName;
                          } catch (e, stackTrace) {
                            debugPrint('[ProfilePage] Error fetching user name: $e');
                            debugPrint('[ProfilePage] Stack trace: $stackTrace');
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
                  onOpenUsers: null,
                  extraActions: [
                    DashButton(
                      label: 'Check for updates',
                      icon: Icons.system_update_alt_rounded,
                      onPressed: () {
                        final updateState = context.read<AppUpdateBloc>().state;

                        if (updateState is AppUpdateAvailableState) {
                          showDialog<void>(
                            context: context,
                            barrierDismissible: !updateState.updateInfo.mandatory,
                            builder: (dialogContext) => UpdateDialog(
                              updateInfo: updateState.updateInfo,
                              onDismiss: () {
                                context.read<AppUpdateBloc>().add(const UpdateDismissedEvent());
                              },
                            ),
                          );
                        } else {
                          context.read<AppUpdateBloc>().add(const CheckUpdateEvent());
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
