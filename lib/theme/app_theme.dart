import 'package:flutter/material.dart';

/// Colores oficiales de la empresa
class AppColors {
  // ========== MODO CLARO - Colores Oficiales ==========
  // Colores principales de la empresa (Negro, Gris, Azul)
  static const Color negro = Color(0xFF000000);
  static const Color navbarOscuro = Color(
    0xFF0b0f18,
  ); // Color para navbar en modo claro
  static const Color gris = Color(0xFF6B7280);
  static const Color grisClaro = Color(0xFF9CA3AF);
  static const Color grisOscuro = Color(0xFF374151);
  static const Color azul = Color(0xFF2563EB);
  static const Color azulClaro = Color(0xFF3B82F6);
  static const Color azulOscuro = Color(0xFF1E40AF);

  // Colores de soporte - Modo Claro
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color fondoClaro = Color(0xFFF9FAFB);

  // ========== MODO OSCURO - Paleta Optimizada ==========
  // Fondos (elevación visual)
  static const Color darkFondoPrincipal = Color(
    0xFF2E3440,
  ); // Gris azulado muy oscuro
  static const Color darkFondoSecundario = Color(
    0xFF3B4252,
  ); // Tarjetas/menús elevados
  static const Color darkFondoTerciario = Color(0xFF434C5E); // Aún más elevado

  // Azules para modo oscuro (desaturados y claros)
  static const Color darkAzulPrimario = Color(0xFF88C0D0); // Azul hielo/cian
  static const Color darkAzulAccent = Color(
    0xFF81A1C1,
  ); // Azul acero para botones
  static const Color darkAzulSutil = Color(0xFF5E81AC); // Azul más sutil

  // Texto modo oscuro
  static const Color darkTexto = Color(
    0xFFECEFF4,
  ); // Blanco nieve (no blanco puro)
  static const Color darkTextoSecundario = Color(
    0xFFD8DEE9,
  ); // Texto secundario
  static const Color darkTextoSutil = Color(0xFF4C566A); // Texto deshabilitado

  // ========== COLORES FUNCIONALES (Ambos Modos) ==========
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(
    0xFFA3BE8C,
  ); // Verde más suave para dark
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFBF616A); // Rojo más suave para dark
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(
    0xFFEBCB8B,
  ); // Naranja más suave para dark
  static const Color info = Color.fromARGB(255, 102, 128, 169);
  static const Color infoDark = Color(0xFF88C0D0); // Azul info para dark
}

/// Tema de la aplicación
class AppTheme {
  // Colores estáticos para acceso directo
  static const Color primaryColor = Color.fromRGBO(136, 192, 208, 1);
  static const Color accentColor = Color.fromRGBO(255, 152, 0, 1);

  // Tema claro (modo día)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Esquema de colores
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF0b0f18), // Color oscuro #0b0f18 para el navbar
      onPrimary: AppColors.blanco,
      secondary: AppColors.gris,
      onSecondary: AppColors.blanco,
      tertiary: AppColors.azulClaro,
      error: AppColors.error,
      onError: AppColors.blanco,
      surface: AppColors.blanco,
      onSurface: AppColors.negro,
      surfaceContainerHighest: AppColors.fondoClaro,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0b0f18), // Color oscuro #0b0f18
      foregroundColor: AppColors.blanco,
      iconTheme: const IconThemeData(color: AppColors.blanco),
      titleTextStyle: const TextStyle(
        color: AppColors.blanco,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.fondoClaro,

    // Card
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.blanco,
      shadowColor: AppColors.negro.withOpacity(0.1),
    ),

    // Botones elevados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.azul,
        foregroundColor: AppColors.blanco,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.azul,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),

    // Botones con borde
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.azul,
        side: const BorderSide(color: AppColors.azul, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Campos de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.blanco,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.grisClaro),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.grisClaro),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.azul, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.gris),
      hintStyle: TextStyle(color: AppColors.grisClaro),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.azul,
      foregroundColor: AppColors.blanco,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grisClaro.withOpacity(0.2),
      deleteIconColor: AppColors.gris,
      labelStyle: const TextStyle(color: AppColors.negro),
      secondaryLabelStyle: const TextStyle(color: AppColors.blanco),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Tabs
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.blanco,
      unselectedLabelColor: AppColors.blanco.withOpacity(0.7),
      indicatorColor: AppColors.blanco,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: AppColors.grisClaro.withOpacity(0.5),
      thickness: 1,
      space: 1,
    ),

    // IconTheme
    iconTheme: const IconThemeData(color: AppColors.gris, size: 24),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.negro,
      contentTextStyle: const TextStyle(color: AppColors.blanco),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.blanco,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: AppColors.negro,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.gris,
      textColor: AppColors.negro,
      tileColor: AppColors.blanco,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ProgressIndicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.azul,
    ),
  );

  // Tema oscuro (modo noche) - Paleta optimizada
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Esquema de colores - Modo Oscuro Optimizado
    colorScheme: ColorScheme.dark(
      primary:
          AppColors.darkAzulPrimario, // Azul hielo para elementos principales
      onPrimary: AppColors.darkFondoPrincipal, // Texto sobre azul
      secondary: AppColors.darkAzulAccent, // Azul acero para secundarios
      onSecondary: AppColors.darkTexto,
      tertiary: AppColors.darkAzulSutil,
      error: AppColors.errorDark,
      onError: AppColors.darkTexto,
      surface: AppColors.darkFondoSecundario, // Tarjetas elevadas
      onSurface: AppColors.darkTexto, // Texto principal
      surfaceContainerHighest: AppColors.darkFondoTerciario, // Elevación máxima
    ),

    // AppBar - Fondo principal oscuro
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppColors.darkFondoPrincipal,
      foregroundColor: AppColors.darkTexto,
      iconTheme: const IconThemeData(color: AppColors.darkTexto),
      titleTextStyle: const TextStyle(
        color: AppColors.darkTexto,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Scaffold - Fondo principal
    scaffoldBackgroundColor: AppColors.darkFondoPrincipal,

    // Card - Fondo secundario (elevado)
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.darkFondoSecundario, // Más claro que el fondo
      shadowColor: AppColors.negro.withOpacity(0.5),
    ),

    // Botones elevados - Azul acero
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkAzulAccent, // Azul acero
        foregroundColor: AppColors.darkTexto,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkAzulPrimario, // Azul hielo
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),

    // Botones con borde
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkTexto,
        side: BorderSide(color: AppColors.darkTextoSutil, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Campos de texto - Fondo secundario
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkFondoSecundario,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.darkTextoSutil),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.darkTextoSutil),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.darkAzulPrimario,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.darkTextoSecundario),
      hintStyle: TextStyle(color: AppColors.darkTextoSutil),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkAzulAccent,
      foregroundColor: AppColors.darkTexto,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkFondoTerciario,
      deleteIconColor: AppColors.darkTextoSecundario,
      labelStyle: const TextStyle(color: AppColors.darkTexto),
      secondaryLabelStyle: const TextStyle(color: AppColors.darkFondoPrincipal),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Tabs - Con buen contraste
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.darkTexto,
      unselectedLabelColor: AppColors.darkTextoSecundario,
      indicatorColor: AppColors.darkAzulPrimario, // Azul hielo
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: AppColors.darkTextoSutil.withOpacity(0.5),
      thickness: 1,
      space: 1,
    ),

    // IconTheme
    iconTheme: const IconThemeData(
      color: AppColors.darkTextoSecundario,
      size: 24,
    ),

    // Snackbar - Fondo elevado
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkFondoTerciario,
      contentTextStyle: const TextStyle(color: AppColors.darkTexto),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    // Dialog - Fondo elevado
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkFondoSecundario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: AppColors.darkTexto,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.darkTextoSecundario,
      textColor: AppColors.darkTexto,
      tileColor: AppColors.darkFondoSecundario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ProgressIndicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.darkAzulPrimario,
    ),
  );
}
