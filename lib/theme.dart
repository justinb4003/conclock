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
