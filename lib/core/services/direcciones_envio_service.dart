import 'package:flutter/foundation.dart';
import '../../models/direccion_envio.dart';
import 'api_service.dart';

class DireccionesEnvioService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<DireccionEnvio> _direcciones = [];

  List<DireccionEnvio> get direcciones => _direcciones;
  DireccionEnvio? get predeterminada =>
      _direcciones.where((d) => d.esPredeterminada).firstOrNull;

  /// Cargar direcciones de envío del usuario
  Future<void> fetchDirecciones() async {
    try {
      final response = await _apiService.get('/direcciones-envio');

      if (response['success']) {
        _direcciones = (response['data'] as List)
            .map((json) => DireccionEnvio.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error al cargar direcciones: $e');
      rethrow;
    }
  }

  /// Crear nueva dirección
  Future<bool> crear(Map<String, dynamic> datos) async {
    try {
      final response = await _apiService.post('/direcciones-envio', datos);

      if (response['success']) {
        final nuevaDireccion = DireccionEnvio.fromJson(response['data']);
        _direcciones.insert(0, nuevaDireccion);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al crear dirección: $e');
      return false;
    }
  }

  /// Actualizar dirección
  Future<bool> actualizar(int id, Map<String, dynamic> datos) async {
    try {
      final response = await _apiService.put('/direcciones-envio/$id', datos);

      if (response['success']) {
        final index = _direcciones.indexWhere((d) => d.id == id);
        if (index != -1) {
          _direcciones[index] = DireccionEnvio.fromJson(response['data']);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al actualizar dirección: $e');
      return false;
    }
  }

  /// Eliminar dirección
  Future<bool> eliminar(int id) async {
    try {
      final response = await _apiService.delete('/direcciones-envio/$id');

      if (response['success']) {
        _direcciones.removeWhere((d) => d.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al eliminar dirección: $e');
      return false;
    }
  }

  /// Establecer como predeterminada
  Future<bool> establecerPredeterminada(int id) async {
    try {
      final response = await _apiService.patch(
        '/direcciones-envio/$id/predeterminada',
      );

      if (response['success']) {
        await fetchDirecciones(); // Recargar para estar sincronizado
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al establecer predeterminada: $e');
      return false;
    }
  }

  /// Limpiar direcciones al cerrar sesión
  void limpiarDirecciones() {
    _direcciones = [];
    notifyListeners();
  }
}
