# GLASS API — verified reference

Source: `liquid_glass_widgets` **1.17.3** (pub.dev archive, extracted 2026-11-14).
Repo: https://github.com/sdegenaar/liquid_glass_widgets

> Rule: never use a `Glass*` symbol that is not listed here.
> If a symbol is missing, open the package source and add it here first.

---

## 1. Naming: `GlassSearchableBottomBar` does NOT exist anymore

`GlassSearchableBottomBar` was the **legacy (v0.x) name**. In v1.x it is:

```dart
GlassTabBar.searchable(...)
```

Source comment (`lib/widgets/surfaces/glass_tab_bar.dart`):

> "This constructor replaces the legacy `GlassSearchableBottomBar`.
> All parameters are identical. Migrate by replacing
> `GlassSearchableBottomBar(` → `GlassTabBar.searchable(`."

So the screenshot's inspector label was from the old demo. Use `GlassTabBar.searchable`.

---

## 2. `GlassTabBar` constructors

```dart
GlassTabBar.bottom({...})       // plain bottom nav
GlassTabBar.searchable({...})   // bottom nav + morphing search
GlassTabBar.minimizable({...})  // bottom nav that minimizes on scroll
GlassTabBar.inline({...})       // in-page switcher
```

### 2.1 `GlassTabBar.searchable` — key params (real)

```dart
const GlassTabBar.searchable({
  required List<GlassTab> tabs,
  required int selectedIndex,
  required ValueChanged<int> onTabSelected,
  required GlassSearchBarConfig searchConfig,
  Key? key,
  SearchableBottomBarController? controller,
  bool isSearchActive = false,
  GlassTabBarExtraButton? extraButton,
  GlassTabBarAccessoryPlacement? bottomAccessoryPlacement,
  Widget? bottomAccessory,
  bool bottomAccessoryEnabled = true,
  double bottomAccessorySpacing = 6.0,
  double? bottomAccessoryHeight,
  double spacing = 8,
  double horizontalPadding = 20,
  double verticalPadding = 20,
  double barHeight = 64,
  double searchBarHeight = 50,
  double barBorderRadius = _kDefaultBottomBorderRadius,
  EdgeInsetsGeometry tabPadding = const EdgeInsets.symmetric(horizontal: 4),
  double iconLabelSpacing = 4,
  bool enableBlend = true,
  bool groupBackdrop = true,
  double blendAmount = 10,
  LiquidGlassSettings? settings,
  bool showIndicator = true,
  Color? indicatorColor,
  LiquidGlassSettings? indicatorSettings,
  double indicatorPinchStrength = 0.4,
  Color? selectedIconColor,
  Color? unselectedIconColor,
  Color? selectedLabelColor,
  Color? unselectedLabelColor,
  TextStyle? selectedLabelStyle,
  TextStyle? unselectedLabelStyle,
  double? iconSize,
  double labelFontSize = 11,
  TextStyle? textStyle,
  Duration glowDuration = const Duration(milliseconds: 300),
  double glowBlurRadius = 32,
  double glowSpreadRadius = 8,
  double glowOpacity = 0.6,
  GlassInteractionBehavior interactionBehavior = GlassInteractionBehavior.full,
  double? pressScale,
  Color? interactionGlowColor,
  double? interactionGlowRadius,
  GlassQuality? quality,
  GlassQuality? backgroundQuality,
  double? magnification,
  double innerBlur = 0.0,
  bool platformViewBackdrop = false,
  bool passthroughOverPlatformView = false,
  MaskingQuality maskingQuality = MaskingQuality.high,
  GlobalKey? backgroundKey,
  SpringDescription? springDescription,
  GlassTabPillAnchor tabPillAnchor = GlassTabPillAnchor.start,
  double? tabWidth,
  double? indicatorBorderRadius,
  EdgeInsetsGeometry indicatorExpansion =
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  VoidCallback? onBarTap,
  bool whitenAtBottom = true,
  double whitenBottomThreshold = 45.0,
  double whitenAtBottomTarget = 1.0,
  ScrollController? scrollController,
  bool adaptiveBrightness = false,
  ValueChanged<Brightness>? onBrightnessChanged,
  ValueListenable<Brightness>? brightnessOverride,
});
```

### 2.2 Mini-player accessory (confirmed)

`GlassTabBar.bottom` / `.searchable` both expose:

- `bottomAccessory` — widget rendered above the pill (iOS 26 `tabViewBottomAccessory`)
- `bottomAccessoryEnabled` — animates in/out via `AnimatedSize`
- `bottomAccessoryHeight` — **must pass** so `GlassScaffold` includes it in `effectiveBottomBarHeight`
- `bottomAccessoryPlacement` — `GlassTabBarAccessoryPlacement.expanded | .inline`

**Important source note:** `GlassTabBar.searchable` keeps its accessory **expanded** while search is open.
Auto-collapsing on search was deliberately removed in 0.x because it hid the mini-player.
So the "collapse into bar on search" behaviour must be implemented by us, not expected from the package.

`GlassTabBarAccessoryPlacementScope.of(context)` exposes current placement inside the accessory.

### 2.3 `GlassTab`

```dart
const GlassTab({
  Widget? icon,
  Widget? activeIcon,
  String? label,
  String? semanticLabel,
  Color? glowColor,
  double? thickness,
});
```

### 2.4 `GlassSearchBarConfig` — key fields

```dart
const GlassSearchBarConfig({
  required ValueChanged<bool> onSearchToggle,
  String hintText = 'Search',
  double? collapsedTabWidth,
  WidgetBuilder? collapsedLogoBuilder,
  Color? searchIconColor,
  Widget? searchIcon,
  Color? micIconColor,
  TextStyle? hintStyle,
  TextEditingController? controller,
  FocusNode? focusNode,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  VoidCallback? onMicTap,
  Color? textColor,
  Color? cursorColor,
  WidgetBuilder? trailingBuilder,
  TextInputAction? textInputAction,
  TextInputType? keyboardType,
  bool autocorrect = true,
  bool enableSuggestions = true,
  TapRegionCallback? onTapOutside,
  bool autoFocusOnExpand = false,
  bool expandWhenActive = true,
  bool showPill = true,
  bool showsCancelButton = true,
  Color? cancelButtonColor,
  Widget? cancelIcon,
  double cancelIconSize = 24,
  ValueChanged<bool>? onSearchFocusChanged,
  VoidCallback? onSearchFieldTap,
  VoidCallback? onCancelTap,
  String? clearButtonSemanticLabel,
  String? micButtonSemanticLabel,
  String? cancelButtonSemanticLabel,
});
```

---

## 3. `LiquidGlassSettings` — the optical model

```dart
const LiquidGlassSettings({
  double visibility = 1.0,
  Color glassColor = const Color.fromARGB(0, 255, 255, 255),
  double thickness = 20,
  double blur = 5,
  double frost = 0.0,
  double frostOpacity = 1.0,
  double frostClamp = 0.0,
  double frostWeight = 1.0,
  double blurWeight = 1.0,
  double chromaticAberration = .01,
  double lightAngle = GlassDefaults.lightAngle, // 0.75 * pi
  double lightIntensity = .5,
  double ambientStrength = 0,
  double ambientRim = 0,
  double fresnelStrength = 1.0,
  double refractiveIndex = 1.2,
  double saturation = 1.5,
  double glowIntensity = 0.75,
  GlassSpecularSharpness specularSharpness = GlassSpecularSharpness.medium,
  double standardOpacityMultiplier = 1.0,
  double shadowElevation = 1.0,
  List<BoxShadow>? shadow,
  double whitenStrength = 0.0,
  bool whitenGated = true,
  double edgeAbsorption = 0.0,
  double rimShade = 0.0,
  double rimShadeEnds = 0.2,
  double rimLight = 0.0,
  double bodyShade = 0.0,
  GlassLensModel lensModel = GlassLensModel.spherical,
  double pinchStrength = ...,     // present on the class
  Color? backerColor,
  Color? platformViewFallbackColor,
  PlatformViewGlassMode platformViewMode = PlatformViewGlassMode.fallbackColor,
  GlassBodyMode bodyMode = GlassBodyMode.adaptive,
});
```

Other constructors: `LiquidGlassSettings.figma({refraction, depth, dispersion, frost, ...})`,
`LiquidGlassSettings._withPinch(...)` (private).

`GlassDefaults` constants:

```
thickness = 30.0      blur = 3.0
lightIntensity = 2.0  chromaticAberration = 0.5
refractiveIndex = 1.15
lightAngle = 0.75 * pi
borderRadius = 16     capsuleRadius = 9999.0
heightControl = 32    heightButton = 48
```

---

## 4. Global theme: `GlassTheme` / `GlassThemeData`

Applied via `LiquidGlassWidgets.wrap(theme: GlassThemeData, ...)` (already used in `main.dart`).

```dart
const GlassThemeData({
  GlassThemeVariant light = GlassThemeVariant.light,
  GlassThemeVariant dark = GlassThemeVariant.dark,
  GlassStyle style = GlassStyle.ios27,
  GlassInteractionSettings interaction = const GlassInteractionSettings(),
  Brightness? brightness,
});

// presets
GlassThemeData.ios27()   // iOS 27 optics
GlassThemeData.ios26()
GlassThemeData.classic()
GlassThemeData.simple(blur:, thickness:, quality:, ...)  // used by settings_manager today

const GlassThemeVariant({
  GlassThemeSettings? settings,
  GlassThemeSettings? indicatorSettings,
  GlassQuality? quality,
  GlassGlowColors? glowColors,
  double? borderRadius,
});
```

`GlassThemeSettings` is a **partial override**: only non-null fields replace widget defaults.
Fields: `visibility, glassColor, thickness, blur, frost, frostOpacity, frostClamp,
frostWeight, blurWeight, chromaticAberration, lightAngle, lightIntensity,
ambientStrength, fresnelStrength, refractiveIndex, saturation, specularSharpness,
edgeAbsorption, rimShade, rimShadeEnds, rimLight, bodyShade, lensModel,
shadowElevation, shadow` (all nullable).

Reading inside widgets:

```dart
final theme = GlassThemeData.of(context);
final settings = theme.settingsFor(context);        // light/dark aware
final indicator = theme.indicatorSettingsFor(context);
```

Brightness cascade: `GlassThemeData.brightness` → Cupertino theme → Material `ThemeMode`
→ `MediaQuery.platformBrightnessOf`.

---

## 5. Adaptive quality

```dart
const GlassAdaptiveScopeConfig({
  GlassQuality minQuality = GlassQuality.minimal,
  GlassQuality maxQuality = GlassQuality.premium,
  GlassQuality? initialQuality,
  int targetFrameMs = 16,
  bool allowStepUp = true,
  double warmupPremiumThresholdMs = 20.0,
  double warmupStandardThresholdMs = 28.0,
  bool frostStep = false,
  void Function(GlassQuality from, GlassQuality to)? onQualityChanged,
  void Function(GlassAdaptiveDiagnostic)? onDiagnostic,
  bool debugLogDiagnostics = false,
});
```

Diagnostics: `GlassAdaptiveScopeData.maybeOf(context)?.effectiveQuality`.

---

## 6. `GlassScaffold`

```dart
const GlassScaffold({
  required Widget body,
  PreferredSizeWidget? appBar,
  Widget? bottomBar,
  Widget? background,
  Color? backgroundColor,
  LiquidGlassSettings? settings,
  GlassStatusBarStyle statusBarStyle = GlassStatusBarStyle.none,
  bool edgeToEdge = false,
  GlassThemeData? themeOverride,
  bool? enableBackgroundSampling,
  double? transitionCornerRadius,
  bool edgeFade = true,
  bool? topEdgeFade,
  bool? bottomEdgeFade,
  bool edgeFadeAbsorbsPointers = false,
  double topEdgeFadeExtent = 20.0,
  double bottomEdgeFadeExtent = 20.0,
  GlassScrollEdgeStyle edgeStyle = GlassScrollEdgeStyle.soft,
  double maxSigma = 18.0,
  bool extendBody = true,
  double appBarHeight = 44.0,
  double? bottomBarHeight,
  bool? resizeToAvoidBottomInset,
  List<Widget>? bodyOverlays,
  Widget? header,
  ScrollController? headerScrollController,
  double headerFadeDistance = 60.0,
  bool contentAwareBrightness = false,
});
```

`bottomBarHeight` is computed from the bar's `preferredSize`; accessory height is included
**only if** `bottomAccessoryHeight` is supplied.

---

## 7. `GlassSegmentedControl`

```dart
const GlassSegmentedControl({
  required List<GlassSegment> segments,
  required int selectedIndex,
  required ValueChanged<int> onSegmentSelected,
  double height = GlassDefaults.heightControl,     // 32
  double borderRadius = GlassDefaults.capsuleRadius,
  double? indicatorBorderRadius,
  EdgeInsetsGeometry padding = const EdgeInsets.all(2),
  TextStyle? selectedTextStyle,
  TextStyle? unselectedTextStyle,
  Color? activeSelectedColor,
  Color? backgroundColor,
  Color? indicatorColor,
  LiquidGlassSettings? indicatorSettings,
  double indicatorPinchStrength = 0.4,
  EdgeInsetsGeometry indicatorExpansion = ...,
  LiquidGlassSettings? settings,
  bool useOwnLayer = false,
  GlassQuality? quality,
  GlobalKey? backgroundKey,
  ScrollController? scrollController,
  SegmentSelectionAlignment selectionAlignment = SegmentSelectionAlignment.minimal,
  Duration regridDuration = Duration.zero,
  SegmentDragBehavior dragBehavior = SegmentDragBehavior.selectIndicator,
  Axis direction = Axis.horizontal,
  double? segmentExtent,
  GlassInteractionBehavior interactionBehavior = GlassInteractionBehavior.full,
  Color? glowColor,
  double glowRadius = 1.5,
  bool isScrollable = false,
  double iconSize = 24.0,
  EdgeInsetsGeometry labelPadding = const EdgeInsets.symmetric(horizontal: 16),
  Color? selectedIconColor,
  Color? unselectedIconColor,
  MaskingQuality maskingQuality = MaskingQuality.high,
  LiquidGlassSettings? dividerSettings,
  List<BoxShadow>? indicatorShadow,
});
```

---

## 8. Our 8 tuner sliders → real params

| Our `GlassConfig` field | Package param | Range / default |
|---|---|---|
| `pinchStrength` | `indicatorPinchStrength` | 0.0–1.0 · 0.40 |
| `expansionH` | `indicatorExpansion.horizontal` | 0–32 px · 12 |
| `expansionV` | `indicatorExpansion.vertical` | 0–32 px · 8 |
| `chromaticAberration` | `LiquidGlassSettings.chromaticAberration` | 0.00–0.50 · 0.15 |
| `tint` | `LiquidGlassSettings.glassColor` alpha | 0.00–1.00 · 0.00 |
| `refraction` | `LiquidGlassSettings.refractiveIndex` | 1.00–1.50 · 1.15 |
| `barRadius` | `GlassTabBar.barBorderRadius` | null → `GlassDefaults.capsuleRadius` |
| `indicatorRadius` | `GlassTabBar.indicatorBorderRadius` | null → auto |

Extra: `blur` and `thickness` remain in the global `GlassThemeSettings` (they were the old sliders).
The Glass Lab will expose only the 8 above; blur/thickness stay at demo-calibrated values.

---

## 9. Traps (real, already hit)

| Trap | Correct |
|---|---|
| `GlassAdaptiveScope.maybeOf` | `GlassAdaptiveScopeData.maybeOf` |
| `GlassSearchableBottomBar` | removed; use `GlassTabBar.searchable` |
| `hide ColorScheme` on package import | package does not export it → `undefined_hidden_name` warning |
| `ThemeMode` mismatch | `app_themes.dart` uses `material_ui`'s ThemeMode; import consistently |
| Search auto-collapses accessory | **not true in v1.x** — implement collapse ourselves |
| `bottomAccessoryHeight` omitted | `GlassScaffold` body inset is wrong → content hides under bar |
| Nested `GlassBackdropGroup` | grey/dull composite; one group per region |
