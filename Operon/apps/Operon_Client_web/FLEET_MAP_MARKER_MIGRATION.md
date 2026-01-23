# Fleet Map Marker Migration Plan

## Deprecation Notice

As of February 21st, 2024, Google Maps deprecated `google.maps.Marker` in favor of `google.maps.marker.AdvancedMarkerElement`.

**Reference:**
- [Google Maps Deprecations](https://developers.google.com/maps/deprecations)
- [Migration Guide](https://developers.google.com/maps/documentation/javascript/advanced-markers/migration)

## Current Status

- **Current Package:** `google_maps_flutter: ^2.14.0`
- **Status:** Package still uses legacy `google.maps.Marker`
- **AdvancedMarkerElement Support:** Not yet available in Flutter package
- **Timeline:** Legacy markers will continue to work for at least 12 months

## Impact

The deprecation warning appears in browser console but does not affect functionality. Legacy markers continue to work normally.

## Migration Plan (When Package Support is Available)

### Files to Update

1. **Marker Generation:**
   - `lib/presentation/utils/marker_generator.dart`
   - `lib/presentation/utils/vehicle_marker_icon_helper.dart`
   - `lib/presentation/utils/bitmap_descriptor_helper.dart`

2. **Marker Usage:**
   - `lib/logic/fleet/fleet_bloc.dart` - Marker creation and management
   - `lib/presentation/views/fleet_map_screen.dart` - Marker rendering
   - `lib/logic/fleet/animated_marker_manager.dart` - Animated markers

### Key Changes Required

1. **Update Package:**
   ```yaml
   google_maps_flutter: ^X.X.X  # Version with AdvancedMarkerElement support
   ```

2. **Marker API Changes:**
   - Replace `Marker` class with `AdvancedMarkerElement` equivalent
   - Update marker creation methods
   - Adjust anchor point handling (uses CSS properties instead of Offset)
   - Update custom icon handling (may need different approach)

3. **Custom Icons:**
   - AdvancedMarkerElement uses `content` property for custom HTML/CSS
   - May need to convert `BitmapDescriptor` to HTML elements
   - Consider using `PinElement` for pin-style markers

4. **Animation:**
   - Update `AnimatedMarkerManager` to work with new marker type
   - Verify position interpolation still works

### Testing Checklist

- [ ] Live mode markers display correctly
- [ ] History mode markers display correctly
- [ ] Custom vehicle badges/icons render properly
- [ ] Marker animations work smoothly
- [ ] Marker tap interactions work
- [ ] Bearing/rotation indicators display correctly
- [ ] Marker clustering (if used) still works

## Monitoring

- **GitHub Issues:**
  - [Flutter Issue #144151](https://github.com/flutter/flutter/issues/144151)
  - [Flutter Issue #130472](https://github.com/flutter/flutter/issues/130472)

- **Package Updates:**
  - Check [pub.dev](https://pub.dev/packages/google_maps_flutter) for new versions
  - Review changelog for AdvancedMarkerElement support

## Notes

- Legacy markers will continue to receive bug fixes
- At least 12 months notice before discontinuation
- No urgent action required until Flutter package adds support
