import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar el tema (modo claro/oscuro) de la aplicación
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _loadTheme();
  }

  /// Cargar tema guardado
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }

      notifyListeners();
    } catch (e) {
      print('Error al cargar tema: $e');
    }
  }

  /// Cambiar a modo oscuro
  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    await _saveTheme('dark');
    notifyListeners();
  }

  /// Cambiar a modo claro
  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    await _saveTheme('light');
    notifyListeners();
  }

  /// Alternar entre modo claro y oscuro
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setLightMode();
    } else {
      await setDarkMode();
    }
  }

  /// Guardar tema en preferencias
  Future<void> _saveTheme(String theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
    } catch (e) {
      print('Error al guardar tema: $e');
    }
  }
}
