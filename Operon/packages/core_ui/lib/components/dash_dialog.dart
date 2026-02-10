import 'package:flutter/material.dart';

import '../theme/auth_colors.dart';
import '../theme/dash_theme.dart';
import 'dash_dialog_header.dart';

/// Standard dialog wrapper that inherits [DashTheme] and applies consistent
/// dark surface styling. Use instead of raw [Dialog] + [ThemeData.dark].copyWith
/// to avoid theme drift and hardcoded colors.
///
/// - Applies [DashTheme.light] (dark surface) with optional [primaryColor].
/// - Standard shape: 24px radius, design-token border and padding.
/// - Optional [DashDialogHeader] when [title] (and [onClose]) are provided.
///
/// For section-specific accents (e.g. fleet purple), pass [primaryColor]:
/// [AuthColors.primary] is used when null.
///
/// When showing via [showDialog], pass [barrierColor] for consistent scrim:
/// `showDialog(context, barrierColor: AuthColors.background.withOpacity(0.7), builder: ...)`.
class DashDialog extends StatelessWidget {
  const DashDialog({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.onClose,
    this.primaryColor,
    this.padding = const EdgeInsets.all(24),
    this.insetPadding = const EdgeInsets.all(24),
    this.constraints,
  });

  /// Dialog body (form, list, etc.).
  final Widget child;

  /// If set, a [DashDialogHeader] is shown above [child]. [onClose] is required when [title] is set.
  final String? title;

  /// Optional subtitle widget for the header.
  final Widget? subtitle;

  /// Optional leading icon for the header.
  final IconData? icon;

  /// Called when the header close button is pressed. Required if [title] is set.
  final VoidCallback? onClose;

  /// Primary/accent color override. Defaults to [AuthColors.primary].
  /// Use e.g. [AuthColors.secondary] for section-specific accents only when needed.
  final Color? primaryColor;

  /// Inner padding around [child]. Defaults to 24px on all sides.
  final EdgeInsetsGeometry padding;

  /// Padding between dialog and screen edges. Defaults to 24px.
  final EdgeInsets insetPadding;

  /// Optional max width/height for the dialog content area.
  final BoxConstraints? constraints;

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final primary = primaryColor ?? AuthColors.primary;
    final theme = DashTheme.light(accentColor: primary);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding,
      child: Theme(
        data: theme,
        child: Container(
          constraints: constraints,
          padding: padding,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: AuthColors.textMain.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AuthColors.background.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null && onClose != null) ...[
                DashDialogHeader(
                  title: title!,
                  subtitle: subtitle,
                  icon: icon,
                  onClose: onClose!,
                  primaryColor: primary,
                ),
                const SizedBox(height: 20),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin for dialog [State] classes to standardize loading state for primary
/// actions. Replaces ad-hoc [CircularProgressIndicator] and manual [setState]
/// with a single [runDialogAction] + [isDialogActionLoading] for [DashButton].
///
/// Example:
/// ```dart
/// class _RecordPaymentDialogState extends State<RecordPaymentDialog>
///     with DialogActionHandler {
///   Future<void> _submitPayment() async {
///     if (!_formKey.currentState!.validate()) return;
///     // ... validation ...
///     await runDialogAction(() async {
///       // ... firestore etc. ...
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return DashDialog(
///       ...
///       child: ...
///       DashButton(
///         label: 'Record Payment',
///         onPressed: ... ? _submitPayment : null,
///         isLoading: isDialogActionLoading,
///       ),
///     );
///   }
/// }
/// ```
mixin DialogActionHandler<T extends StatefulWidget> on State<T> {
  bool _dialogActionLoading = false;

  /// Whether the dialog primary action is in progress. Pass to [DashButton.isLoading].
  bool get isDialogActionLoading => _dialogActionLoading;

  /// Runs [action] and sets loading true before and false after (in finally).
  /// Use for submit/save handlers so [DashButton] shows loading state consistently.
  Future<void> runDialogAction(Future<void> Function() action) async {
    if (_dialogActionLoading) return;
    setState(() => _dialogActionLoading = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _dialogActionLoading = false);
      }
    }
  }
}
