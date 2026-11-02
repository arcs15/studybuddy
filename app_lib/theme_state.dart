import 'package:flutter/material.dart';

/// Light / Dark / System choice, saved in settings.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeFromName(String? n) =>
    ThemeMode.values.firstWhere((m) => m.name == n, orElse: () => ThemeMode.system);
