import 'package:flutter/material.dart';

import 'models.dart';

/// The app's default color (Settings → Color).
const defaultAppColor = 0xFF1E88E5;

/// Material 3 theme from the app color. [background] mixes more of the
/// color into the surfaces (page, cards, navigation) than Material does
/// on its own.
ThemeData buildTheme(Brightness brightness, int appColor, Backdrop background) {
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
