import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_theme/system_theme.dart';

enum ThemeFlavor { standard, pitchBlack, ocean, forest }

class AppTheme {
  
  static FluentThemeData getTheme(Brightness brightness, bool useGlass, ThemeFlavor flavor) {
    // Logic: If Light Mode -> Text is Black. If Dark Mode -> Text is White.
    final textColor = brightness == Brightness.light ? Colors.black : Colors.white;

    TextStyle font(double size, FontWeight weight) => 
      GoogleFonts.jetBrainsMono(
        fontSize: size, 
        fontWeight: weight,
        color: textColor // FORCE THE COLOR
      );

    final typography = Typography.raw(
      display: font(68, FontWeight.w600),
      titleLarge: font(40, FontWeight.w600),
      title: font(28, FontWeight.w600),
      subtitle: font(20, FontWeight.w600),
      bodyLarge: font(16, FontWeight.w400),
      bodyStrong: font(14, FontWeight.w600),
      body: font(14, FontWeight.w400),
      caption: font(12, FontWeight.w400),
    );

    // --- BACKGROUND LOGIC ---
    Color bgColor;
    
    if (flavor == ThemeFlavor.pitchBlack) {
      // Void Mode: Opaque Black. No Glass.
      bgColor = const Color(0xFF000000);
    } else if (useGlass) {
      // Glass Mode with Tints
      if (flavor == ThemeFlavor.ocean) {
        bgColor = const Color(0xFF001F3F).withValues(alpha: 0.3); // Deep Blue Tint
      } else if (flavor == ThemeFlavor.forest) {
        bgColor = const Color(0xFF0B3B0B).withValues(alpha: 0.3); // Deep Green Tint
      } else {
        // Standard Glass
        bgColor = brightness == Brightness.dark 
            ? Colors.black.withValues(alpha: 0.2) 
            : const Color(0xFFFFFFFF).withValues(alpha: 0.5);
      }
    } else {
      // Solid Mode (No Glass)
      bgColor = brightness == Brightness.dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3);
    }

    // --- CARD LOGIC ---
    // Pitch Black cards need to be slightly lighter than the void background
    final cardColor = (flavor == ThemeFlavor.pitchBlack)
        ? const Color(0xFF141414)
        : (brightness == Brightness.dark 
            ? const Color(0xFF2D2D2D).withValues(alpha: useGlass ? 0.6 : 1.0)
            : const Color(0xFFFFFFFF).withValues(alpha: useGlass ? 0.7 : 1.0));

    return FluentThemeData(
      brightness: brightness,
      accentColor: SystemTheme.accentColor.accent.toAccentColor(),
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: bgColor,
      typography: typography,
      cardColor: cardColor,
      
      // Fix Navigation Pane colors
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: bgColor,
        unselectedIconColor: WidgetStateProperty.resolveWith((states) {
          return states.isHovered 
            ? textColor 
            : textColor.withValues(alpha: 0.7);
        }),
        selectedIconColor: WidgetStateProperty.all(textColor),
      ),
      
      iconTheme: IconThemeData(color: textColor),
    );
  }
}