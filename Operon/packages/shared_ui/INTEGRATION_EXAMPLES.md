# Integration Examples

## Android App Integration

### Replacing QuickNavBar in `home_page.dart`

```dart
import 'package:shared_ui/shared_ui.dart';

// In your HomePage widget, replace QuickNavBar with:

SharedFloatingNavBar(
  items: [
    NavBarItem(
      icon: Icons.home_rounded,
      label: 'Home',
      heroTag: 'nav_home',
    ),
    NavBarItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending Orders',
      heroTag: 'nav_pending',
    ),
    NavBarItem(
      icon: Icons.schedule_rounded,
      label: 'Schedule',
      heroTag: 'nav_schedule',
    ),
    NavBarItem(
      icon: Icons.map_rounded,
      label: 'Map',
      heroTag: 'nav_map',
    ),
    NavBarItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      heroTag: 'nav_dashboard',
    ),
  ],
  currentIndex: homeState.currentIndex,
  onItemTapped: (index) {
    context.read<HomeCubit>().switchToSection(index);
  },
  visibleIndices: homeState.allowedSections,
)
```

### Replacing QuickActionMenu in `home_page.dart`

```dart
import 'package:shared_ui/shared_ui.dart';

// Replace QuickActionMenu with:

if (homeState.currentIndex == 0 || homeState.currentIndex == 1)
  SmartActionFab(
    actions: [
      ActionItem(
        icon: Icons.receipt,
        label: 'Add Expense',
        onTap: () {
          context.go('/record-expense');
        },
      ),
      ActionItem(
        icon: Icons.payment,
        label: 'Payments',
        onTap: () {
          context.go('/record-payment');
        },
      ),
      ActionItem(
        icon: Icons.shopping_cart,
        label: 'Record Purchase',
        onTap: () {
          context.go('/record-purchase');
        },
      ),
      ActionItem(
        icon: Icons.add_shopping_cart_outlined,
        label: 'Create Order',
        onTap: () {
          PendingOrdersView.showCustomerTypeDialog(context);
        },
      ),
    ],
  ),
```

## Web App Integration

### In `section_workspace_layout.dart`

```dart
import 'package:shared_ui/shared_ui.dart';

// Add SharedFloatingNavBar at the top of your layout
SharedFloatingNavBar(
  items: [
    NavBarItem(
      icon: Icons.home_rounded,
      label: 'Overview',
      heroTag: 'nav_overview',
    ),
    NavBarItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending Orders',
      heroTag: 'nav_pending',
    ),
    // ... more items
  ],
  currentIndex: currentIndex,
  onItemTapped: (index) {
    // Handle navigation
  },
)

// Replace QuickActionMenu with SmartActionFab
SmartActionFab(
  actions: actions, // Your dynamic action list
  right: 40,
  bottom: 40,
)
```

## Adding to pubspec.yaml

### Android App (`apps/Operon_Client_android/pubspec.yaml`)

```yaml
dependencies:
  shared_ui:
    path: ../../packages/shared_ui
```

### Web App (`apps/Operon_Client_web/pubspec.yaml`)

```yaml
dependencies:
  shared_ui:
    path: ../../packages/shared_ui
```

## Migration Checklist

- [ ] Add `shared_ui` dependency to both apps' `pubspec.yaml`
- [ ] Run `melos bootstrap` at repo root
- [ ] Replace `QuickNavBar` with `SharedFloatingNavBar` in Android app
- [ ] Replace `QuickActionMenu` with `SmartActionFab` in both apps
- [ ] Update imports from `quick_nav_bar.dart` to `shared_ui`
- [ ] Update imports from `quick_action_menu.dart` to `shared_ui`
- [ ] Test navigation and action menu interactions
- [ ] Verify animations are smooth and performant
- [ ] Test on both platforms (Android and Web)
