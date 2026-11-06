import 'package:flutter/material.dart';

class AppColors {
  AppColors._(this.light);
  factory AppColors.of(BuildContext context) =>
      AppColors._(Theme.of(context).brightness == Brightness.light);

  final bool light;
  Color get background =>
      light ? const Color(0xFFF3F7F8) : const Color(0xFF15142F);
  Color get surface => light ? Colors.white : const Color(0xFF242144);
  Color get inner => light ? const Color(0xFFEFF5F5) : const Color(0xFF1B1938);
  Color get border => light ? const Color(0xFFD0DEE0) : const Color(0xFF393254);
  Color get muted => light ? const Color(0xFF52666A) : const Color(0xFFA39DBF);
  Color get cyan => light ? const Color(0xFF006E78) : const Color(0xFF36C9D8);
  Color get green => light ? const Color(0xFF137749) : const Color(0xFF65D99A);
  Color get text => light ? const Color(0xFF172F33) : Colors.white;
  Color get headerEnd =>
      light ? const Color(0xFFE3F0EF) : const Color(0xFF282347);
}

class AppThemeScope extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const AppThemeScope({
    super.key,
    required ValueNotifier<ThemeMode> controller,
    required super.child,
  }) : super(notifier: controller);

  static ValueNotifier<ThemeMode>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.notifier;
}
