import 'package:flutter/material.dart';

/// Paleta de colores oficial de la marca RinGo! (Basada en las imágenes de referencia)
class AppColors {
  // Primario de acento
  static const Color primaryYellow = Color(0xFFFFC800); // Amarillo vibrante de marca
  static const Color yellowAccent = Color(0xFFFFD000);

  // Secundarios y contraste
  static const Color blackPure = Color(0xFF000000);
  static const Color darkGray = Color(0xFF1E1E1E);
  static const Color mediumGray = Color(0xFF757575);
  static const Color borderGray = Color(0xFFE0E0E0);

  // Fondos claros
  static const Color lightBackground = Color(0xFFF5F5F5); // Gris claro neutro
  static const Color white = Color(0xFFFFFFFF);

  // Acentos para mapas e interfaz
  static const Color pastelGreen = Color(0xFFA5D6A7); // Zonas destacadas / parques
  static const Color lightBlueRoute = Color(0xFF64B5F6); // Trazado de ruta
}

/// Temas globales de la aplicación: Light Theme (por defecto) y Dark Theme
class AppTheme {
  // --- TEMA CLARO (LIGHT MODE) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryYellow,
        onPrimary: AppColors.blackPure,
        secondary: AppColors.blackPure,
        onSecondary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.blackPure,
      ),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.blackPure,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.blackPure,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.blackPure),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryYellow,
          foregroundColor: AppColors.blackPure,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blackPure,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.blackPure, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: const TextStyle(color: AppColors.mediumGray, fontWeight: FontWeight.w500),
        prefixIconColor: AppColors.blackPure,
        suffixIconColor: AppColors.blackPure,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderGray, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderGray, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryYellow, width: 2.5),
        ),
      ),
    );
  }

  // --- TEMA OSCURO (DARK MODE) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.blackPure,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryYellow,
        onPrimary: AppColors.blackPure,
        secondary: AppColors.primaryYellow,
        onSecondary: AppColors.blackPure,
        surface: AppColors.darkGray,
        onSurface: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blackPure,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkGray,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryYellow,
          foregroundColor: AppColors.blackPure,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIconColor: AppColors.primaryYellow,
        suffixIconColor: AppColors.primaryYellow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryYellow, width: 2.5),
        ),
      ),
    );
  }
}

/// Logotipo y Branding 'RinGo! DELIVERY | MOTOTAXI' (según la referencia)
class RingoBrandHeader extends StatelessWidget {
  final double fontSize;
  final bool isDarkBackground;
  final bool showSubtitle;

  const RingoBrandHeader({
    super.key,
    this.fontSize = 28,
    this.isDarkBackground = false,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkBackground ? AppColors.white : AppColors.blackPure;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono angular de flecha estilizada RinGo! (como en el bolso de la imagen)
            Container(
              width: fontSize * 1.1,
              height: fontSize * 1.1,
              decoration: const BoxDecoration(
                color: AppColors.primaryYellow,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.near_me_rounded,
                  color: AppColors.blackPure,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: textColor,
                ),
                children: const [
                  TextSpan(text: 'Rin'),
                  TextSpan(
                    text: 'Go!',
                    style: TextStyle(color: AppColors.primaryYellow),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 3),
          Text(
            'DELIVERY | MOTOTAXI',
            style: TextStyle(
              fontSize: fontSize * 0.32,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: isDarkBackground ? AppColors.primaryYellow : AppColors.blackPure.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón circular negro con flecha blanca '→' (exacto a las referencias visuales)
class RingoCircleArrowButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const RingoCircleArrowButton({
    super.key,
    required this.onTap,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.blackPure,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador de Origen / Recogida (Target concéntrico: Aro negro, amarillo vibrante, centro negro)
class RingoOriginTargetMarker extends StatelessWidget {
  const RingoOriginTargetMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blackPure,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryYellow,
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blackPure,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador de Destino / Entrega (Pin teardrop negro con círculo amarillo central)
class RingoDestinationPinMarker extends StatelessWidget {
  const RingoDestinationPinMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pin negro de base
          const Icon(
            Icons.location_on,
            color: AppColors.blackPure,
            size: 48,
          ),
          // Punto amarillo en el cabezal del pin
          Positioned(
            top: 10,
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: AppColors.primaryYellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
