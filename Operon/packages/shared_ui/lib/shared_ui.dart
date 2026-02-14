library shared_ui;

import 'package:core_ui/components/navigation/action_fab.dart'
    show ActionFab;
import 'package:core_ui/components/navigation/floating_nav_bar.dart'
    show FloatingNavBar;

// Re-export from core_ui for backward compatibility
// These components have been moved to core_ui for consistency
export 'package:core_ui/components/navigation/floating_nav_bar.dart'
    show FloatingNavBar, NavBarItem;
export 'package:core_ui/components/navigation/action_fab.dart'
    show ActionFab, ActionItem;

// Type aliases for backward compatibility with old names
typedef SharedFloatingNavBar = FloatingNavBar;
typedef SmartActionFab = ActionFab;
