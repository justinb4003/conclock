import 'package:flutter/material.dart';

import 'models.dart';

/// The app's default color (Settings → Color).
const defaultAppColor = 0xFF1E88E5;

/// The app font when Settings -> "Dyslexia-friendly font" is on (bundled).
const dyslexicFont = 'OpenDyslexic';

/// Material 3 theme from the app color. [background] mixes more of the
/// color into the surfaces (page, cards, navigation) than Material does
/// on its own. [dyslexic] sets all text in [dyslexicFont].
ThemeData buildTheme(
  Brightness brightness,
  int appColor,
  Backdrop background, {
  bool dyslexic = false,
}) {
  var scheme = ColorScheme.fromSeed(
    seedColor: Color(appColor),
    brightness: brightness,
  );
  final mix = switch (background) {
    Backdrop.neutral => 0.0,
    Backdrop.tinted => 0.08,
    Backdrop.bold => 0.18,
  };
  if (mix > 0) {
    final tint = scheme.primary.withValues(alpha: mix);
    Color t(Color c) => Color.alphaBlend(tint, c);
    scheme = scheme.copyWith(
      surface: t(scheme.surface),
      surfaceDim: t(scheme.surfaceDim),
      surfaceBright: t(scheme.surfaceBright),
      surfaceContainerLowest: t(scheme.surfaceContainerLowest),
      surfaceContainerLow: t(scheme.surfaceContainerLow),
      surfaceContainer: t(scheme.surfaceContainer),
      surfaceContainerHigh: t(scheme.surfaceContainerHigh),
      surfaceContainerHighest: t(scheme.surfaceContainerHighest),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    fontFamily: dyslexic ? dyslexicFont : null,
    // OpenDyslexic runs wide: at 11px, slightly tightened, "Timesheet"
    // fits a small phone's navigation bar on one line. Colors as Material's
    // defaults.
    navigationBarTheme: dyslexic
        ? NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                letterSpacing: -0.6,
                color: states.contains(WidgetState.selected)
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          )
        : null,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

final _clientSchemes = <(int, Brightness), ColorScheme>{};

/// Material colors derived from a client's color, for anything that draws
/// on it (icons, check marks): the raw palette colors don't contrast
/// enough in one theme or the other. `primary` keeps the hue; `onPrimary`
/// reads on it.
ColorScheme clientScheme(BuildContext context, int color) {
  final brightness = Theme.of(context).brightness;
  return _clientSchemes[(color, brightness)] ??= ColorScheme.fromSeed(
    seedColor: Color(color),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
}

/// Black or white, whichever contrasts more with [background] (a check
/// mark on a color swatch).
Color checkColorOn(Color background) {
  final l = background.computeLuminance() + 0.05;
  return 1.05 / l >= l / 0.05 ? Colors.white : Colors.black;
}
