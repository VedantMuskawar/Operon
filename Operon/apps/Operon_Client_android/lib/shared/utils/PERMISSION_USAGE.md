# Permission Helper Usage Guide

This guide shows how to use the `PermissionHelper` utility in new pages to check user permissions.

## Basic Usage

### 1. Import the Permission Helper

```dart
import 'package:dash_mobile/shared/utils/permission_helper.dart';
```

### 2. Check Permissions in Your Page

```dart
class MyNewPage extends StatelessWidget {
  const MyNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user can access this page
    final canAccess = PermissionHelper.canAccessPage(context, 'myPageKey');
    if (!canAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    // Check CRUD permissions
    final canCreate = PermissionHelper.canCreate(context, 'myPageKey');
    final canEdit = PermissionHelper.canEdit(context, 'myPageKey');
    final canDelete = PermissionHelper.canDelete(context, 'myPageKey');

    return Scaffold(
      appBar: AppBar(title: const Text('My Page')),
      body: Column(
        children: [
          if (canCreate)
            ElevatedButton(
              onPressed: () => _createItem(),
              child: const Text('Create'),
            ),
          // ... rest of your page
        ],
      ),
    );
  }
}
```

### 3. Add Route with Permission Check

In `app_router.dart`:

```dart
GoRoute(
  path: '/my-page',
  name: 'my-page',
  pageBuilder: (context, state) {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final role = orgState.role;
    
    if (organization == null || role == null) {
      return _buildTransitionPage(
        key: state.pageKey,
        child: const OrganizationSelectionPage(),
      );
    }
    
    // Check permission
    if (!role.canAccessPage('myPageKey') && !role.isAdmin) {
      return _buildTransitionPage(
        key: state.pageKey,
        child: const HomePage(),
      );
    }
    
    return _buildTransitionPage(
      key: state.pageKey,
      child: BlocProvider(
        create: (_) => MyPageCubit(
          canCreate: role.canCreate('myPageKey'),
          canEdit: role.canEdit('myPageKey'),
          canDelete: role.canDelete('myPageKey'),
        )..load(),
        child: const MyPage(),
      ),
    );
  },
),
```

### 4. Add Page to Access Control

In `access_control_page.dart`, add your page to the `_pages` list:

```dart
const _pages = [
  // ... existing pages
  _PageInfo('myPageKey', 'My Page', Icons.my_icon, Color(0xFF6F4BFF)),
];
```

## Available Methods

- `PermissionHelper.canCreate(context, pageKey)` - Check create permission
- `PermissionHelper.canEdit(context, pageKey)` - Check edit permission
- `PermissionHelper.canDelete(context, pageKey)` - Check delete permission
- `PermissionHelper.canAccessPage(context, pageKey)` - Check page access
- `PermissionHelper.canAccessSection(context, sectionKey)` - Check section access
- `PermissionHelper.isAdmin(context)` - Check if user is admin

## Page Keys

Use consistent page keys that match what you add to Access Control:
- `products`
- `employees`
- `users` (admin-only)
- `clients`
- `zonesCity`, `zonesRegion`, `zonesPrice`
- `vehicles`
- `paymentAccounts` (admin-only)
- `roles` (admin-only)
- `accessControl` (admin-only)

## Section Keys

For navigation sections:
- `pendingOrders`
- `scheduleOrders`
- `ordersMap`
- `analyticsDashboard`

## Notes

- Admin users automatically have all permissions
- If a role doesn't have a page in their permissions, they cannot access it
- Always check permissions before showing action buttons or allowing operations

