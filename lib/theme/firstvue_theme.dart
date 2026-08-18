import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand accent colors shared across light and dark modes.
/// Prefer [FirstVueColors.of] / [BuildContext.fv] for surfaces and text.
class FirstVueColors {
  FirstVueColors._();

  // Brand accents (work on both themes)
  static const gold = Color(0xFFE5C16F);
  static const warmGold = Color(0xFFD8B56A);
  static const teal = Color(0xFF3DD9C9);
  static const coral = Color(0xFFFF7A59);
  static const blush = Color(0xFFD68E98);
  static const ivory = Color(0xFFF4EFE6);
  static const mutedIcon = Color(0xFF8A9099);
  static const mutedRed = Color(0xFFE39A9A);

  /// Ink on gold fills (buttons, VUE mark, selected pills). White-on-gold reads flat.
  static const onGold = Color(0xFF0B1020);

  /// Soft gold halo used on primary CTAs and the VUE tab.
  static List<BoxShadow> goldGlow({double intensity = 1, bool pressed = false}) {
    final alpha = pressed ? 0.14 * intensity : 0.38 * intensity;
    return [
      BoxShadow(
        color: gold.withValues(alpha: alpha),
        blurRadius: pressed ? 8 : 22,
        spreadRadius: pressed ? 0 : 1,
        offset: Offset(0, pressed ? 1 : 5),
      ),
    ];
  }

  // Legacy dark defaults — prefer Theme / FirstVuePalette when possible.
  static const background = Color(0xFF0E0B1A);
  static const surface = Color(0xFF161222);
  static const elevatedSurface = Color(0xFF1C1829);

  static FirstVuePalette of(BuildContext context) =>
      Theme.of(context).extension<FirstVuePalette>() ?? FirstVuePalette.dark;
}

/// Semantic FirstVue colors that flip with light/dark ThemeData.
@immutable
class FirstVuePalette extends ThemeExtension<FirstVuePalette> {
  const FirstVuePalette({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.icon,
    required this.mutedIcon,
    required this.divider,
    required this.navBar,
    required this.success,
    required this.error,
    required this.warning,
    required this.mediaControl,
    required this.mediaControlBg,
    required this.inputFill,
    required this.borderSubtle,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color icon;
  final Color mutedIcon;
  final Color divider;
  final Color navBar;
  final Color success;
  final Color error;
  final Color warning;
  final Color mediaControl;
  final Color mediaControlBg;
  final Color inputFill;
  final Color borderSubtle;

  static const dark = FirstVuePalette(
    background: Color(0xFF0E0B1A),
    surface: Color(0xFF161222),
    elevatedSurface: Color(0xFF1C1829),
    primaryText: Color(0xFFF4EFE6),
    secondaryText: Color(0xB3F4EFE6),
    tertiaryText: Color(0x73F4EFE6),
    icon: Color(0xFFF4EFE6),
    mutedIcon: Color(0xFF8A9099),
    divider: Color(0x22F4EFE6),
    navBar: Color(0xFF0E0B1A),
    success: Color(0xFF3DD9C9),
    error: Color(0xFFE39A9A),
    warning: Color(0xFFE5C16F),
    mediaControl: Color(0xFFF4EFE6),
    mediaControlBg: Color(0x990E0B1A),
    inputFill: Color(0xFF1C1829),
    borderSubtle: Color(0x2E3DD9C9),
  );

  /// White social FirstVue — canvas is pure white with gold/teal accents.
  static const light = FirstVuePalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFF4F4F6),
    primaryText: Color(0xFF16131F),
    secondaryText: Color(0xFF5A5668),
    tertiaryText: Color(0xFF8A8696),
    icon: Color(0xFF16131F),
    mutedIcon: Color(0xFF7A7686),
    divider: Color(0x1A16131F),
    navBar: Color(0xFFFFFFFF),
    success: Color(0xFF0D9B8C),
    error: Color(0xFFC04545),
    warning: Color(0xFFB8860B),
    mediaControl: Color(0xFFFFFFFF),
    mediaControlBg: Color(0x990E0B1A),
    inputFill: Color(0xFFF3F4F6),
    borderSubtle: Color(0x1416131F),
  );

  @override
  FirstVuePalette copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? icon,
    Color? mutedIcon,
    Color? divider,
    Color? navBar,
    Color? success,
    Color? error,
    Color? warning,
    Color? mediaControl,
    Color? mediaControlBg,
    Color? inputFill,
    Color? borderSubtle,
  }) {
    return FirstVuePalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      icon: icon ?? this.icon,
      mutedIcon: mutedIcon ?? this.mutedIcon,
      divider: divider ?? this.divider,
      navBar: navBar ?? this.navBar,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      mediaControl: mediaControl ?? this.mediaControl,
      mediaControlBg: mediaControlBg ?? this.mediaControlBg,
      inputFill: inputFill ?? this.inputFill,
      borderSubtle: borderSubtle ?? this.borderSubtle,
    );
  }

  @override
  FirstVuePalette lerp(ThemeExtension<FirstVuePalette>? other, double t) {
    if (other is! FirstVuePalette) return this;
    return FirstVuePalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      mutedIcon: Color.lerp(mutedIcon, other.mutedIcon, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      mediaControl: Color.lerp(mediaControl, other.mediaControl, t)!,
      mediaControlBg: Color.lerp(mediaControlBg, other.mediaControlBg, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
    );
  }
}

extension FirstVueThemeContext on BuildContext {
  FirstVuePalette get fv => FirstVueColors.of(this);
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}

class FirstVueTheme {
  FirstVueTheme._();

  static const _serif = 'CormorantGaramond';
  static const _sans = 'SpaceGrotesk';

  /// Preserves the current FirstVue dark visual identity in ThemeData.
  static ThemeData get elegantDark => _build(
    brightness: Brightness.dark,
    palette: FirstVuePalette.dark,
    scheme: const ColorScheme.dark(
      surface: Color(0xFF0E0B1A),
      primary: FirstVueColors.gold,
      secondary: FirstVueColors.teal,
      tertiary: FirstVueColors.coral,
      onPrimary: FirstVueColors.onGold,
      onSecondary: Color(0xFF071315),
      onSurface: FirstVueColors.ivory,
      error: Color(0xFFE39A9A),
    ),
    buttonForeground: FirstVueColors.onGold,
    labelMuted: Colors.white60,
    hintMuted: Colors.white38,
    overlayStyle: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: FirstVuePalette.dark.navBar,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  /// Proper native-looking light FirstVue theme (not a dark invert).
  static ThemeData get elegantLight => _build(
    brightness: Brightness.light,
    palette: FirstVuePalette.light,
    scheme: const ColorScheme.light(
      surface: Color(0xFFFFFFFF),
      primary: FirstVueColors.gold,
      secondary: FirstVueColors.teal,
      tertiary: FirstVueColors.coral,
      onPrimary: FirstVueColors.onGold,
      onSecondary: Color(0xFF071315),
      onSurface: Color(0xFF16131F),
      error: Color(0xFFC04545),
    ),
    buttonForeground: FirstVueColors.onGold,
    labelMuted: Color(0xFF5A5668),
    hintMuted: Color(0xFF8A8696),
    overlayStyle: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: FirstVuePalette.light.navBar,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  /// Back-compat alias used across the codebase.
  static ThemeData get theme => elegantDark;

  static ThemeData _build({
    required Brightness brightness,
    required FirstVuePalette palette,
    required ColorScheme scheme,
    required Color buttonForeground,
    required Color labelMuted,
    required Color hintMuted,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: _sans,
      scaffoldBackgroundColor: palette.background,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      iconTheme: IconThemeData(color: palette.icon),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        displayMedium: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        displaySmall: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        headlineLarge: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        headlineMedium: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        headlineSmall: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        titleLarge: TextStyle(
          fontFamily: _serif,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
        ),
        titleMedium: TextStyle(color: palette.primaryText),
        titleSmall: TextStyle(color: palette.primaryText),
        bodyLarge: TextStyle(color: palette.primaryText),
        bodyMedium: TextStyle(color: palette.primaryText),
        bodySmall: TextStyle(color: palette.secondaryText),
        labelLarge: TextStyle(color: palette.primaryText),
        labelMedium: TextStyle(color: palette.secondaryText),
        labelSmall: TextStyle(color: palette.tertiaryText),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.primaryText,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: TextStyle(
          fontFamily: _serif,
          color: palette.primaryText,
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
        iconTheme: IconThemeData(color: palette.icon),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? FirstVueColors.teal.withValues(alpha: .18)
                : palette.borderSubtle,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _serif,
          color: palette.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: palette.secondaryText),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        labelStyle: TextStyle(color: labelMuted),
        hintStyle: TextStyle(color: hintMuted),
        prefixIconColor: FirstVueColors.gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: FirstVueColors.teal.withValues(alpha: isDark ? .55 : .75),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FirstVueColors.gold,
          foregroundColor: buttonForeground,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FirstVueColors.gold,
          foregroundColor: buttonForeground,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? FirstVueColors.teal : FirstVueColors.gold,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          side: BorderSide(
            width: 1.4,
            color: (isDark ? FirstVueColors.teal : FirstVueColors.gold)
                .withValues(alpha: .85),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? FirstVueColors.teal : FirstVueColors.gold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.navBar,
        indicatorColor: FirstVueColors.coral.withValues(alpha: .14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FirstVueColors.coral);
          }
          return IconThemeData(color: palette.mutedIcon);
        }),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
            color: palette.secondaryText,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevatedSurface,
        contentTextStyle: TextStyle(color: palette.primaryText),
        actionTextColor: FirstVueColors.teal,
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      dividerColor: palette.divider,
      listTileTheme: ListTileThemeData(
        iconColor: palette.icon,
        textColor: palette.primaryText,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FirstVueColors.teal,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FirstVueColors.teal;
          }
          return palette.mutedIcon;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FirstVueColors.teal.withValues(alpha: .35);
          }
          return palette.elevatedSurface;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FirstVueColors.teal;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: palette.mutedIcon),
      ),
    );
  }
}
