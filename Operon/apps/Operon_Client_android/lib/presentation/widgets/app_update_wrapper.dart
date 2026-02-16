import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/app_update/app_update_bloc.dart';
import 'package:dash_mobile/presentation/blocs/app_update/app_update_event.dart';
import 'package:dash_mobile/presentation/blocs/app_update/app_update_state.dart';
import 'package:dash_mobile/presentation/widgets/update_dialog.dart';

/// Wrapper widget that checks for app updates when the app starts
/// and handles showing the update dialog
class AppUpdateWrapper extends StatefulWidget {
  final Widget child;

  const AppUpdateWrapper({
    required this.child,
    super.key,
  });

  @override
  State<AppUpdateWrapper> createState() => _AppUpdateWrapperState();
}

class _AppUpdateWrapperState extends State<AppUpdateWrapper> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    // Check for updates on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  void _checkForUpdate() {
    if (!_updateChecked) {
      _updateChecked = true;
      context.read<AppUpdateBloc>().add(const CheckUpdateEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdateBloc, AppUpdateState>(
      listener: (context, state) {
        if (state is AppUpdateAvailableState) {
          // Show update dialog when update is available
          _showUpdateDialog(context, state.updateInfo);
        } else if (state is AppUpdateErrorState) {
          debugPrint('App update error: ${state.message}');
        }
      },
      child: widget.child,
    );
  }

  /// Show the update dialog
  void _showUpdateDialog(BuildContext context, updateInfo) {
    showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.mandatory,
      builder: (BuildContext dialogContext) => UpdateDialog(
        updateInfo: updateInfo,
        onDismiss: () {
          context.read<AppUpdateBloc>().add(const UpdateDismissedEvent());
        },
      ),
    );
  }
}
