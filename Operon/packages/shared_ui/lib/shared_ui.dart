library shared_ui;

// Re-export from core_ui for backward compatibility
// These components have been moved to core_ui for consistency
export 'package:core_ui/core_ui.dart' show
    FloatingNavBar,
    NavBarItem,
    ActionFab,
    ActionItem;

// Type aliases for backward compatibility with old names
typedef SharedFloatingNavBar = FloatingNavBar;
typedef SmartActionFab = ActionFab;
