---
name: Port Android UI to Web
overview: Port all UI, styling, and optimization improvements from the Android app to the web app, including design system constants, theme enhancements, modern widgets, TexturedBackground, ColorUtils, and optimized list views, while preserving existing section_workspace_layout and page_workspace_layout widgets.
todos:
  - id: create-constants-structure
    content: Create shared/constants directory structure and port all constants files (app_colors, app_spacing, app_typography, app_shadows, constants.dart)
    status: pending
  - id: add-color-utils
    content: Port ColorUtils class to shared/utils/color_utils.dart with hex color conversion and secondary color generation
    status: pending
  - id: update-theme-accent
    content: Update buildDashTheme in app_theme.dart to support optional accentColor parameter matching Android implementation
    status: pending
    dependencies:
      - create-constants-structure
  - id: port-textured-background
    content: Port TexturedBackground widget optimized for web (consider performance implications and CSS alternatives)
    status: pending
    dependencies:
      - create-constants-structure
  - id: port-modern-tile
    content: Port ModernTile, ModernTileWithAvatar, and ModernProductTile widgets adapted for web layouts
    status: pending
    dependencies:
      - create-constants-structure
  - id: port-modern-header
    content: Port ModernPageHeader widget ensuring compatibility with web routing (go_router)
    status: pending
    dependencies:
      - create-constants-structure
  - id: port-optimized-list
    content: Port OptimizedListView with loading/error/empty states optimized for web scrolling performance
    status: pending
    dependencies:
      - create-constants-structure
  - id: update-login-colors
    content: Update login_page.dart colors to match Android's pure black theme (0xFF000000 and 0xFF0A0A0A)
    status: pending
    dependencies:
      - create-constants-structure
  - id: integrate-background-app
    content: Integrate TexturedBackground in app.dart MaterialApp.builder with web-optimized settings (optional/conditional)
    status: pending
    dependencies:
      - port-textured-background
  - id: verify-workspace-layouts
    content: Verify section_workspace_layout and page_workspace_layout still function correctly after changes
    status: pending
    dependencies:
      - create-constants-structure
      - port-modern-tile
      - port-modern-header
  - id: update-existing-pages
    content: Gradually update existing web pages to use new constants and modern widgets where appropriate
    status: pending
    dependencies:
      - create-constants-structure
      - port-modern-tile
      - port-modern-header
      - port-optimized-list
  - id: test-responsive-behavior
    content: Test responsive behavior across desktop/tablet sizes and verify theme consistency
    status: pending
    dependencies:
      - verify-workspace-layouts
      - update-existing-pages
---

# Port Android UI, Styling, and Optimizations to Web App

This plan documents all UI, styling, and optimization changes from the Android app that need to be ported to the web app, tailored for web while preserving the existing workspace layout widgets.

## Key Changes Identified

### 1. Design System Constants
- **Location**: Android has a comprehensive constants system in `lib/shared/constants/`
- **Files to port**:
  - `app_colors.dart` - Centralized color definitions with AppColors class
  - `app_spacing.dart` - Standardized spacing values (padding, margins, gaps, border radius, icon sizes)
  - `app_typography.dart` - Standardized text styles
  - `app_shadows.dart` - Standardized shadow definitions
  - `constants.dart` - Main export file

**Action**: Create `apps/Operon_Client_web/lib/shared/constants/` directory and port all constants files, adapting colors/spacing as needed for web display.

### 2. Theme Configuration Enhancement
- **Android**: `buildDashTheme({Color? accentColor})` - supports optional accent color parameter
- **Web**: `buildDashTheme()` - no accent color support

**Action**: Update [apps/Operon_Client_web/lib/config/app_theme.dart](apps/Operon_Client_web/lib/config/app_theme.dart) to match Android's signature and support accent colors.

### 3. Color Utilities
- **Android**: `lib/shared/utils/color_utils.dart` with ColorUtils class
  - `hexToColor()` - Converts hex strings to Color objects
  - `hexToColorWithFallback()` - With fallback color support
  - `generateSecondaryColor()` - Generates lighter accent colors

**Action**: Port ColorUtils to `apps/Operon_Client_web/lib/shared/utils/color_utils.dart`.

### 4. TexturedBackground Widget
- **Android**: `lib/presentation/widgets/textured_background.dart` - Provides textured background patterns (grain, dotted, diagonal)
- **Usage**: Wrapped around entire app in MaterialApp.builder
- **Features**: Background patterns, opacity control, debug mode

**Action**: Port TexturedBackground widget to web, adapt for web performance (consider CSS-based alternatives or optimized Canvas rendering).

### 5. Modern UI Widgets
- **Android widgets not present in web**:
  - `modern_tile.dart` - ModernTile, ModernTileWithAvatar, ModernProductTile components
  - `modern_page_header.dart` - ModernPageHeader with consistent styling
  - `optimized_list_view.dart` - OptimizedListView with built-in loading/error/empty states

**Action**: Port these widgets to web, adapting for web-specific layouts (desktop-first responsive design).

### 6. Login Page Color Updates
- **Android**: `_outerBackground = Color(0xFF000000)`, `_panelColor = Color(0xFF0A0A0A)`
- **Web**: `_outerBackground = Color(0xFF020205)`, `_panelColor = Color(0xFF0B0B12)`

**Action**: Update [apps/Operon_Client_web/lib/presentation/views/login_page.dart](apps/Operon_Client_web/lib/presentation/views/login_page.dart) to match Android's pure black theme colors.

### 7. App Builder Configuration
- **Android**: Uses TexturedBackground in MaterialApp.builder
- **Web**: No background texture

**Action**: Update [apps/Operon_Client_web/lib/presentation/app.dart](apps/Operon_Client_web/lib/presentation/app.dart) to optionally include TexturedBackground (consider making it web-optimized or optional).

### 8. Missing Loading/Error/Empty State Widgets
- **Android**: Has dedicated widgets in `lib/presentation/widgets/empty/` and `lib/presentation/widgets/error/`
- **Web**: Need to verify if these exist

**Action**: Check if EmptyStateWidget and ErrorStateWidget exist in web app, port if missing.

### 9. Preserved Widgets (DO NOT REMOVE)
- **section_workspace_layout.dart** - Keep as-is, used extensively across web app
- **page_workspace_layout.dart** - Keep as-is, used for page-level layouts

## Implementation Strategy

### Phase 1: Design System Foundation
1. Create constants directory structure
2. Port AppColors, AppSpacing, AppTypography, AppShadows
3. Update existing code to use constants where applicable

### Phase 2: Theme and Utilities
1. Add accentColor parameter to buildDashTheme
2. Port ColorUtils
3. Update theme usage throughout app

### Phase 3: Modern Widgets
1. Port ModernTile components (adapt for web layouts)
2. Port ModernPageHeader (ensure compatibility with web routing)
3. Port OptimizedListView (optimize for web scrolling performance)

### Phase 4: Background and Visual Enhancements
1. Port TexturedBackground (optimize for web - consider reduced opacity or CSS alternative)
2. Update login page colors to match Android
3. Integrate TexturedBackground in app.dart (make optional/optimized for web)

### Phase 5: Integration and Testing
1. Update existing pages to use new constants and widgets where appropriate
2. Ensure section_workspace_layout and page_workspace_layout continue working
3. Test responsive behavior on desktop/tablet sizes
4. Verify theme consistency across all pages

## Web-Specific Considerations

1. **Performance**: TexturedBackground may impact web performance - consider:
   - Lower opacity defaults
   - CSS-based alternative for web
   - Optional feature flag
   - Canvas optimization

2. **Responsive Design**: ModernTile and other widgets should adapt well to desktop layouts (already designed with this in mind)

3. **Spacing**: Web may benefit from slightly larger spacing values - review AppSpacing for desktop-friendly defaults

4. **Typography**: Font sizes may need adjustment for desktop viewing - ensure readability

5. **Shadows**: Box shadows may render differently on web - test and adjust if needed

## Files to Modify

- `apps/Operon_Client_web/lib/config/app_theme.dart` - Add accentColor support
- `apps/Operon_Client_web/lib/presentation/app.dart` - Optional TexturedBackground integration
- `apps/Operon_Client_web/lib/presentation/views/login_page.dart` - Update colors

## Files to Create

- `apps/Operon_Client_web/lib/shared/constants/constants.dart`
- `apps/Operon_Client_web/lib/shared/constants/app_colors.dart`
- `apps/Operon_Client_web/lib/shared/constants/app_spacing.dart`
- `apps/Operon_Client_web/lib/shared/constants/app_typography.dart`
- `apps/Operon_Client_web/lib/shared/constants/app_shadows.dart`
- `apps/Operon_Client_web/lib/shared/utils/color_utils.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/textured_background.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/modern_tile.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/modern_page_header.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/lists/optimized_list_view.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/empty/empty_state_widget.dart` (if missing)
- `apps/Operon_Client_web/lib/presentation/widgets/error/error_state_widget.dart` (if missing)
- `apps/Operon_Client_web/lib/presentation/widgets/loading/loading_skeleton.dart` (if missing)

## Testing Checklist

- [ ] All constants are accessible and working
- [ ] Theme supports accent colors
- [ ] TexturedBackground renders properly on web (performance acceptable)
- [ ] Modern widgets work in desktop layouts
- [ ] Login page matches Android styling
- [ ] section_workspace_layout and page_workspace_layout still function correctly
- [ ] No regressions in existing pages
- [ ] Responsive behavior works correctly
- [ ] Color consistency across app
- [ ] Typography is readable on desktop screens