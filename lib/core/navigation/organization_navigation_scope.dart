import 'package:flutter/widgets.dart';

/// Provides callbacks for organization shell navigation so child views can
/// trigger top-level navigation without tight coupling to the shell widget.
class OrganizationNavigationScope extends InheritedWidget {
  const OrganizationNavigationScope({
    super.key,
    required super.child,
    required this.goHome,
    required this.goToView,
    required this.currentView,
  });

  /// Callback to return to the organization home dashboard.
  final VoidCallback goHome;

  /// Callback to switch to a specific view id managed by the shell.
  final void Function(String viewId) goToView;

  /// The identifier for the currently rendered view.
  final String currentView;

  static OrganizationNavigationScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OrganizationNavigationScope>();
  }

  @override
  bool updateShouldNotify(OrganizationNavigationScope oldWidget) {
    return currentView != oldWidget.currentView ||
        goHome != oldWidget.goHome ||
        goToView != oldWidget.goToView;
  }
}


