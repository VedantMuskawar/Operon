# Shared UI Package

Modern, performant navigation and action menu components with glassmorphic design.

## Components

### `SharedFloatingNavBar`

A floating pill-shaped navigation bar with glassmorphic background and smooth animations.

**Features:**
- Glassmorphic design with backdrop blur
- Platform-aware: Top center on Web, Bottom center on Android
- Icon + Label on Web, Icon-only on Android
- Animated selection indicator
- Haptic feedback on Android
- Role-based visibility support

**Usage:**

```dart
import 'package:shared_ui/shared_ui.dart';

SharedFloatingNavBar(
  items: [
    NavBarItem(
      icon: Icons.home_rounded,
      label: 'Home',
      heroTag: 'nav_home',
    ),
    NavBarItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending',
      heroTag: 'nav_pending',
    ),
    // ... more items
  ],
  currentIndex: currentIndex,
  onItemTapped: (index) {
    // Handle navigation
  },
  visibleIndices: [0, 1, 2], // Optional: role-based visibility
)
```

### `SmartActionFab`

A creative floating action button menu with staggered spring animations.

**Features:**
- Main button rotates 45° to 'X' when expanded
- Action buttons pop out with bouncy spring effect
- Dynamic action list support
- Glassmorphic action buttons
- Optimized backdrop blur

**Usage:**

```dart
import 'package:shared_ui/shared_ui.dart';

SmartActionFab(
  actions: [
    ActionItem(
      icon: Icons.receipt,
      label: 'Add Expense',
      onTap: () {
        // Handle action
      },
    ),
    ActionItem(
      icon: Icons.payment,
      label: 'Payments',
      onTap: () {
        // Handle action
      },
    ),
    // ... more actions
  ],
  onStateChanged: (isExpanded) {
    // Optional: track menu state
  },
)
```

## Performance

- Uses `RepaintBoundary` to isolate animations
- Optimized backdrop blur that doesn't redraw the whole screen
- Lightweight `Container` decorations instead of heavy shape layers
- Context-aware animations that react instantly to state changes

## Design System

- Primary gradient: `#6F4BFF` to `#8B6FFF`
- Glassmorphic blur: `sigmaX: 10, sigmaY: 10`
- Spring animations with `Curves.elasticOut` for bouncy effects
- Smooth transitions with `Curves.easeOutCubic`
