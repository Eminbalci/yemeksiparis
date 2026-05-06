import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeController extends ChangeNotifier {
  // Singleton Pattern
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  String _currentRole = 'customer'; // Default role is 'customer'
  String get currentRole => _currentRole;

  void updateRole(String role) {
    String formattedRole = role == 'Müşteri Girişi' || role == 'customer' || role == 'Müşteri' 
        ? 'customer' 
        : 'restaurant_owner';
    
    if (_currentRole != formattedRole) {
      _currentRole = formattedRole;
      notifyListeners();
    }
  }

  // Get active ThemeData based on the selected role
  ThemeData get activeTheme {
    final bool isCustomer = _currentRole == 'customer';
    
    final Color primaryColor = isCustomer 
        ? const Color(0xFFFF5722) // Sunset Orange for hunger and warmth
        : const Color(0xFF06D6A0); // Vibrant Emerald Green for business & analytics
        
    final Color secondaryColor = isCustomer 
        ? const Color(0xFFFFB703) // Warm Honey Amber
        : const Color(0xFF4361EE); // High-Tech Indigo

    final Color scaffoldBg = isCustomer 
        ? const Color(0xFF110E0C) // Charcoal Brown (appetizing, deep dark)
        : const Color(0xFF0A0F1D); // Cyber slate/navy for analytics look

    final Color cardBg = isCustomer 
        ? const Color(0xFF1E1715) // Deep reddish-brown card
        : const Color(0xFF131B2E); // Sleek slate navy card

    final TextTheme baseTextTheme = ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: primaryColor,
      cardColor: cardBg,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardBg,
        onPrimary: isCustomer ? Colors.white : Colors.black,
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isCustomer ? Colors.white : Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 4,
          shadowColor: primaryColor.withValues(alpha: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.9)),
        bodyMedium: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.65)),
        bodySmall: GoogleFonts.outfit(color: Colors.white54),
      ),
    );
  }
}
