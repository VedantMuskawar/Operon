import 'package:dash_mobile/data/services/notification_token_service.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationTokenBootstrap extends StatefulWidget {
  const NotificationTokenBootstrap({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NotificationTokenBootstrap> createState() =>
      _NotificationTokenBootstrapState();
}

class _NotificationTokenBootstrapState
    extends State<NotificationTokenBootstrap> {
  final NotificationTokenService _service = NotificationTokenService();
  String? _userId;
  String? _phoneNumber;
  String? _organizationId;

  Future<void> _sync() async {
    final userId = _userId;
    final orgId = _organizationId;
    if (userId != null && orgId != null) {
      await _service.start(
        organizationId: orgId,
        userId: userId,
        phoneNumber: _phoneNumber,
      );
    } else {
      await _service.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) {
            return previous.userProfile?.id != current.userProfile?.id ||
                previous.userProfile?.phoneNumber !=
                    current.userProfile?.phoneNumber;
          },
          listener: (context, state) {
            _userId = state.userProfile?.id;
            _phoneNumber = state.userProfile?.phoneNumber;
            _sync();
          },
        ),
        BlocListener<OrganizationContextCubit, OrganizationContextState>(
          listenWhen: (previous, current) {
            return previous.organization?.id != current.organization?.id;
          },
          listener: (context, state) {
            _organizationId = state.organization?.id;
            _sync();
          },
        ),
      ],
      child: widget.child,
    );
  }
}
