# UI Layers - Client and Contact Pages (Android App)

## Clients Page (`clients_page.dart`)

### Main Structure
```
1. Scaffold
   ├── backgroundColor: AuthColors.background
   ├── appBar: ModernPageHeader
   │   └── title: 'Clients'
   └── body: SafeArea
       └── Stack
           ├── Column (Main Layout)
           │   ├── Expanded
           │   │   └── Column
           │   │       ├── Expanded
           │   │       │   └── PageView
           │   │       │       ├── physics: PageScrollPhysics
           │   │       │       ├── Page 0: _ClientsListView
           │   │       │       └── Page 1: ClientAnalyticsPage
           │   │       ├── SizedBox (spacing: 12)
           │   │       ├── StandardPageIndicator
           │   │       └── SizedBox (spacing: 24)
           │   └── QuickNavBar
           └── Positioned (Floating Action Button)
               ├── Material
               ├── InkWell
               └── Container (FAB styling)
```

### _ClientsListView Widget Structure
```
2. _ClientsListView (StatelessWidget)
   └── BlocBuilder<ClientsCubit, ClientsState>
       └── Conditional Rendering:
           ├── Error State: SingleChildScrollView
           │   └── Column
           │       ├── StandardSearchBar
           │       ├── SizedBox
           │       ├── _ClientFilterChips
           │       ├── SizedBox
           │       └── ErrorStateWidget
           │
           └── Normal State: CustomScrollView
               └── Slivers:
                   ├── SliverPadding
                   │   └── SliverToBoxAdapter
                   │       └── Column
                   │           ├── StandardSearchBar
                   │           ├── SizedBox
                   │           ├── _ClientFilterChips
                   │           ├── SizedBox
                   │           └── Padding (Client count)
                   │               └── Text
                   │
                   ├── Conditional Slivers:
                   │   ├── Loading: SliverFillRemaining
                   │   │   └── Center
                   │   │       └── CircularProgressIndicator
                   │   │
                   │   ├── Search Active: SliverToBoxAdapter
                   │   │   └── _SearchResultsCard
                   │   │
                   │   ├── Empty: SliverFillRemaining
                   │   │   └── _EmptyClientsState
                   │   │
                   │   └── Has Data:
                   │       ├── SliverToBoxAdapter
                   │       │   └── Row
                   │       │       ├── Expanded
                   │       │       │   └── Text ("Recently added clients")
                   │       │       └── CircularProgressIndicator (conditional)
                   │       ├── SliverToBoxAdapter (spacing)
                   │       └── AnimationLimiter
                   │           └── SliverList
                   │               └── SliverChildBuilderDelegate
                   │                   └── AnimationConfiguration.staggeredList
                   │                       ├── SlideAnimation
                   │                       └── FadeInAnimation
                   │                           └── Padding
                   │                               └── _ClientTile
```

### Component Widgets in Clients Page
```
3. StandardSearchBar
   └── (Custom search bar widget)

4. _ClientFilterChips
   └── SingleChildScrollView (horizontal)
       └── Row
           ├── StandardChip ("All")
           ├── SizedBox
           ├── StandardChip ("Corporate")
           ├── SizedBox
           └── StandardChip ("Individual")

5. _ClientTile
   └── Container
       └── DataList
           ├── title: Text (client name)
           ├── subtitle: Text (phone + type)
           ├── leading: DataListAvatar
           │   ├── initial: Text (initials)
           │   └── statusRingColor: Color
           └── trailing: Row
               ├── Container (Order count badge)
               │   └── Row
               │       ├── Icon
               │       └── Text
               └── Wrap (Tags)
                   └── Container (per tag)
                       └── Text

6. _SearchResultsCard
   └── Container
       ├── decoration: BoxDecoration
       └── Column
           ├── Row
           │   ├── Expanded
           │   │   └── Text ("Search Results")
           │   └── TextButton ("Clear")
           ├── SizedBox
           └── Conditional:
               ├── Loading: CircularProgressIndicator
               ├── Empty: _EmptySearchState
               └── Results: Column
                   └── _ClientTile (mapped)

7. _EmptyClientsState
   └── EmptyStateWidget
       ├── icon: Icons.people_outline
       ├── title: Text
       ├── message: Text
       └── actionButton: DashButton

8. _EmptySearchState
   └── Container
       └── Column
           ├── Icon
           ├── SizedBox
           ├── Text ("No results found")
           └── Text (query message)

9. StandardPageIndicator
   └── (Custom page indicator widget)

10. QuickNavBar
    └── (Custom navigation bar widget)

11. Floating Action Button (FAB)
    └── Positioned
        └── Material
            └── InkWell
                └── Container
                    ├── decoration: BoxDecoration (gradient)
                    └── Icon (add icon)
```

---

## Contact Page (`contact_page.dart`)

### Main Structure
```
1. Scaffold
   ├── backgroundColor: AuthColors.background
   └── body: SafeArea
       └── Column
           ├── Padding (Header)
           │   └── Row
           │       ├── IconButton (close)
           │       ├── SizedBox
           │       ├── Expanded
           │       │   └── Text ("Contact")
           │       └── SizedBox
           │
           └── Expanded
               └── Column
                   ├── Expanded
                   │   └── PageView
                   │       ├── physics: ClampingScrollPhysics
                   │       ├── allowImplicitScrolling: false
                   │       ├── Page 0: SingleChildScrollView
                   │       │   ├── physics: ClampingScrollPhysics
                   │       │   └── _CallLogsCard
                   │       │
                   │       └── Page 1: RefreshIndicator
                   │           └── SingleChildScrollView
                   │               ├── controller: _contactListController
                   │               ├── physics: ClampingScrollPhysics
                   │               └── _ContactSearchCard
                   │
                   ├── SizedBox (spacing: 12)
                   ├── _PageIndicator
                   └── SizedBox (spacing: 24)
```

### _CallLogsCard Widget Structure
```
2. _CallLogsCard
   └── DecoratedBox
       ├── decoration: BoxDecoration
       │   ├── color: Color(0xFF1B1B2C)
       │   ├── borderRadius: 24
       │   └── border: Border
       └── Padding
           └── Column
               ├── Conditional:
               │   ├── Loading: Padding
               │   │   └── Center
               │   │       └── CircularProgressIndicator
               │   │
               │   ├── Empty: _EmptyState
               │   │
               │   └── Has Data: Column
               │       └── _CallLogSection (mapped per day)
               │           ├── Text (day title)
               │           ├── SizedBox
               │           └── _CallLogTile (mapped)
```

### _CallLogTile Widget Structure
```
3. _CallLogTile
   └── Padding
       └── InkWell
           └── DecoratedBox
               ├── decoration: BoxDecoration
               │   ├── color: AuthColors.surface
               │   ├── borderRadius: 14
               │   └── border: Border
               └── Padding
                   └── Row
                       ├── DecoratedBox (Icon container)
                       │   └── SizedBox
                       │       └── Icon (call made/received)
                       ├── SizedBox
                       ├── Expanded
                       │   └── Column
                       │       ├── Text (contact name)
                       │       └── Text (phone number)
                       └── Column
                           ├── Text (time)
                           └── Text (duration)
```

### _ContactSearchCard Widget Structure
```
4. _ContactSearchCard
   └── DecoratedBox
       ├── decoration: BoxDecoration
       │   ├── color: Color(0xFF1B1B2C)
       │   ├── borderRadius: 24
       │   └── border: Border
       └── Padding
           └── Column
               ├── Text ("Search Contacts")
               ├── SizedBox
               ├── Text (description)
               ├── SizedBox
               ├── TextField
               │   └── decoration: InputDecoration
               │       ├── prefixIcon: Icon
               │       ├── hintText
               │       ├── filled: true
               │       ├── fillColor
               │       └── border: OutlineInputBorder
               ├── SizedBox
               └── Conditional:
                   ├── Loading: CircularProgressIndicator
                   │
                   └── Content:
                       ├── Conditional Message: Text
                       │
                       └── Main Content:
                           ├── Recent Contacts (if any):
                           │   ├── Text ("Recently searched")
                           │   ├── SizedBox
                           │   └── SizedBox
                           │       └── ListView.separated (horizontal)
                           │           └── ActionChip (per contact)
                           │
                           └── Contact List:
                               ├── Empty: Text
                               │
                               └── Has Results: ListView.builder
                                   ├── shrinkWrap: true
                                   ├── physics: NeverScrollableScrollPhysics
                                   ├── itemExtent: 72
                                   ├── cacheExtent: 300
                                   └── itemBuilder:
                                       ├── _AnimatedContactTile
                                       ├── Loading indicator (if loadingMore)
                                       └── Load more text (if hasMore)
```

### _AnimatedContactTile Widget Structure
```
5. _AnimatedContactTile (StatefulWidget)
   └── FadeTransition
       └── SlideTransition
           └── RepaintBoundary
               └── _ContactListTile
```

### _ContactListTile Widget Structure
```
6. _ContactListTile
   └── Material
       └── InkWell
           └── Padding
               └── Row
                   ├── CircleAvatar
                   │   ├── backgroundColor
                   │   └── Text (initials)
                   ├── SizedBox
                   ├── Expanded
                   │   └── Column
                   │       ├── Text (contact name)
                   │       └── Text (phone)
                   └── Icon (chevron_right)
```

### _PageIndicator Widget Structure
```
7. _PageIndicator
   └── Row
       └── List.generate
           └── AnimatedContainer
               ├── width: 18 or 8 (based on active)
               ├── height: 8
               └── decoration: BoxDecoration
                   ├── color: AuthColors.legacyAccent or transparent
                   └── borderRadius: 999
```

### _EmptyState Widget Structure
```
8. _EmptyState
   └── Center
       └── Column
           ├── DecoratedBox (Icon container)
           │   └── SizedBox
           │       └── Icon
           ├── SizedBox
           └── Text (message)
```

### Dialog Widgets in Contact Page
```
9. _ContactActionSheet (Dialog)
   └── Dialog
       └── Container
           ├── constraints: BoxConstraints
           ├── padding
           ├── decoration: BoxDecoration
           └── Column
               ├── Row (header)
               │   ├── Expanded
               │   │   └── Text
               │   └── IconButton (close)
               ├── Text (description)
               ├── SizedBox
               ├── ListTile ("New Client")
               │   ├── leading: Container (icon)
               │   ├── title: Text
               │   └── subtitle: Text
               ├── SizedBox
               └── ListTile ("Add to Existing")
                   ├── leading: Container (icon)
                   ├── title: Text
                   └── subtitle: Text

10. _ExistingClientPickerSheet (Dialog)
    └── Dialog
        └── Container
            ├── constraints: BoxConstraints
            ├── padding
            ├── decoration: BoxDecoration
            └── Column
                ├── Row (header)
                ├── SizedBox
                ├── TextField (search)
                ├── SizedBox
                └── Conditional:
                    ├── Loading: CircularProgressIndicator
                    ├── Error: Text
                    ├── Empty: Text
                    └── Results: Flexible
                        └── ListView.separated
                            └── ListTile (per client)
                                ├── title: Text
                                ├── subtitle: Text
                                └── trailing: Icon

11. _DuplicateClientSheet (Dialog)
    └── Dialog
        └── Container
            ├── constraints: BoxConstraints
            ├── padding
            ├── decoration: BoxDecoration
            └── Column
                ├── Row (header)
                ├── SizedBox
                ├── Text (client name)
                ├── SizedBox
                ├── ListTile ("View existing")
                ├── Divider
                └── ListTile ("Cancel")

12. _AddContactToClientSheet (Dialog)
    └── Dialog
        └── GestureDetector
            └── Container
                ├── constraints: BoxConstraints
                ├── padding
                ├── decoration: BoxDecoration
                └── SingleChildScrollView
                    └── Column
                        ├── Row (header)
                        ├── SizedBox
                        ├── Wrap (tags)
                        ├── SizedBox
                        ├── TextField (name)
                        ├── SizedBox
                        ├── Conditional:
                        │   ├── Multiple phones: DropdownButtonFormField
                        │   └── Single phone: Container
                        │       └── Column
                        │           └── Text (display phone)
                        ├── Conditional (if corporate):
                        │   ├── SizedBox
                        │   └── TextField (description)
                        ├── Error message (conditional)
                        ├── SizedBox
                        └── ElevatedButton ("Add Contact")

13. _ClientFormSheet (Dialog)
    └── Dialog
        └── GestureDetector
            └── Container
                ├── constraints: BoxConstraints
                ├── padding
                ├── decoration: BoxDecoration
                └── SingleChildScrollView
                    └── Column
                        ├── Row (header)
                        ├── SizedBox
                        ├── TextField (name)
                        ├── SizedBox
                        ├── Text ("Tag")
                        ├── SizedBox
                        ├── Wrap
                        │   └── ChoiceChip (per tag)
                        ├── SizedBox
                        ├── Conditional:
                        │   ├── Multiple phones: DropdownButtonFormField
                        │   └── Single phone: Container
                        ├── Error message (conditional)
                        ├── SizedBox
                        └── ElevatedButton ("Save Client")
```

---

## Summary of Core UI Widgets Used

### Layout Widgets
- `Scaffold` - Main page structure
- `SafeArea` - Safe area insets handling
- `Stack` - Overlay positioning (Clients Page FAB)
- `Column` - Vertical layout
- `Row` - Horizontal layout
- `Padding` - Spacing
- `Expanded` - Flexible sizing
- `SizedBox` - Spacing/sizing
- `Positioned` - Absolute positioning (FAB)

### Scroll Widgets
- `CustomScrollView` - Custom scrollable area (Clients Page)
- `SingleChildScrollView` - Simple scrollable content
- `PageView` - Swipeable pages
- `ListView.builder` - Dynamic list (Contact Page)
- `ListView.separated` - List with separators
- `RefreshIndicator` - Pull-to-refresh

### Sliver Widgets (Clients Page)
- `SliverPadding` - Padding for slivers
- `SliverToBoxAdapter` - Convert regular widget to sliver
- `SliverList` - List sliver with animations
- `SliverFillRemaining` - Fill remaining space
- `SliverChildBuilderDelegate` - Builder for sliver children

### Animation Widgets
- `AnimationLimiter` - Limit animations
- `AnimationConfiguration.staggeredList` - Staggered list animations
- `AnimationConfiguration.staggeredGrid` - Staggered grid animations
- `SlideAnimation` - Slide animation wrapper
- `FadeInAnimation` - Fade animation wrapper
- `FadeTransition` - Fade transition (Contact tiles)
- `SlideTransition` - Slide transition (Contact tiles)
- `AnimatedContainer` - Animated container (Page indicator)
- `RepaintBoundary` - Performance optimization

### Input Widgets
- `TextField` - Text input
- `TextEditingController` - Text field controller
- `DropdownButtonFormField` - Dropdown selection

### Display Widgets
- `Text` - Text display
- `Icon` - Icon display
- `IconButton` - Clickable icon
- `Image` - Image display (not used in these pages)
- `CircleAvatar` - Circular avatar
- `DataList` - Custom list item widget
- `DataListAvatar` - Avatar for DataList

### Container & Decoration Widgets
- `Container` - Generic container (FAB, badges, tags)
- `DecoratedBox` - Box with decoration (Cards, tiles)
- `BoxDecoration` - Decoration properties
- `LinearGradient` - Gradient colors (FAB)
- `BorderRadius` - Rounded corners
- `Border` - Border styling

### Interactive Widgets
- `InkWell` - Material ripple effect
- `GestureDetector` - Gesture handling
- `Material` - Material widget
- `ElevatedButton` - Button widget
- `TextButton` - Text button
- `ListTile` - List item with tap
- `ActionChip` - Action chip
- `ChoiceChip` - Selectable chip

### Feedback Widgets
- `CircularProgressIndicator` - Loading indicator
- `SnackBar` - Toast message (via ScaffoldMessenger)

### Dialog Widgets
- `Dialog` - Modal dialog
- `showDialog` - Show dialog function

### Navigation Widgets
- `Navigator` - Navigation stack
- `MaterialPageRoute` - Page route
- `go_router` - Router navigation

### Custom Widgets (from core_ui package)
- `ModernPageHeader` - Custom app bar
- `StandardSearchBar` - Custom search bar
- `StandardChip` - Custom chip widget
- `StandardPageIndicator` - Page indicator
- `QuickNavBar` - Navigation bar
- `EmptyStateWidget` - Empty state display
- `ErrorStateWidget` - Error state display
- `DataList` - Custom list item component
- `DataListAvatar` - Avatar component

### State Management
- `BlocBuilder` - BLoC state builder
- `BlocListener` - BLoC state listener
- `context.watch` - Watch state changes
- `context.read` - Read state

---

## Key Differences

### Clients Page
- Uses **CustomScrollView with Slivers** for efficient scrolling
- Has **PageView** for switching between Clients List and Analytics
- Has **Floating Action Button** in Stack
- Uses **AnimationLimiter** with **SliverList** for staggered animations
- Has **filter chips** for filtering clients

### Contact Page
- Uses **PageView** for Call Logs and Contacts sections
- Has **RefreshIndicator** for pull-to-refresh
- Uses **DecoratedBox** instead of Container (optimized)
- Has **ListView.builder** with fixed item heights for performance
- Has **multiple dialog sheets** for user interactions
- Uses **AnimatedContainer** for page indicator dots

---

## Performance Optimizations Applied

1. **Slivers** - Efficient scrolling in Clients Page
2. **ListView.builder** - Lazy loading in Contact Page
3. **itemExtent** - Fixed item heights for better performance
4. **RepaintBoundary** - Isolated repaints
5. **shrinkWrap** - Size to content when needed
6. **cacheExtent** - Limited cache size
7. **ClampingScrollPhysics** - Faster scroll physics
8. **DecoratedBox instead of Container** - Better performance
9. **AnimationLimiter** - Limits animation rebuilds
10. **Staggered animations** - 200ms duration, 30ms delay
