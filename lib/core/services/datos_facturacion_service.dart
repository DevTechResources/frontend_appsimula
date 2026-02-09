import 'package:flutter/foundation.dart';
import '../../models/datos_facturacion.dart';
import 'api_service.dart';

class DatosFacturacionService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<DatosFacturacion> _datos = [];

  List<DatosFacturacion> get datos => _datos;
  DatosFacturacion? get predeterminado =>
      _datos.where((d) => d.esPredeterminado).firstOrNull;

  /// Cargar datos de facturación del usuario
  Future<void> fetchDatos() async {
    try {
      final response = await _apiService.get('/datos-facturacion');

      if (response['success']) {
        _datos = (response['data'] as List)
            .map((json) => DatosFacturacion.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error al cargar datos de facturación: $e');
      rethrow;
    }
  }

  /// Crear nuevos datos de facturación
  Future<bool> crear(Map<String, dynamic> datos) async {
    try {
      final response = await _apiService.post('/datos-facturacion', datos);

      if (response['success']) {
        final nuevoDato = DatosFacturacion.fromJson(response['data']);
        _datos.insert(0, nuevoDato);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al crear datos de facturación: $e');
      return false;
    }
  }

  /// Actualizar datos de facturación
  Future<bool> actualizar(int id, Map<String, dynamic> datos) async {
    try {
      final response = await _apiService.put('/datos-facturacion/$id', datos);

      if (response['success']) {
        final index = _datos.indexWhere((d) => d.id == id);
        if (index != -1) {
          _datos[index] = DatosFacturacion.fromJson(response['data']);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al actualizar datos de facturación: $e');
      return false;
    }
  }

  /// Eliminar datos de facturación
  Future<bool> eliminar(int id) async {
    try {
      final response = await _apiService.delete('/datos-facturacion/$id');

      if (response['success']) {
        _datos.removeWhere((d) => d.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al eliminar datos de facturación: $e');
      return false;
    }
  }

  /// Establecer como predeterminado
  Future<bool> establecerPredeterminado(int id) async {
    try {
      final response = await _apiService.patch(
        '/datos-facturacion/$id/predeterminado',
      );

      if (response['success']) {
        // Actualizar estado local
        for (var dato in _datos) {
          dato = DatosFacturacion.fromJson({
            ...dato.toJson(),
            'id': dato.id,
            'cliente_id': dato.clienteId,
            'es_predeterminado': dato.id == id,
            'activo': dato.activo,
            'created_at': dato.createdAt.toIso8601String(),
            'updated_at': dato.updatedAt.toIso8601String(),
          });
        }
        await fetchDatos(); // Recargar para estar sincronizado
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al establecer predeterminado: $e');
      return false;
    }
  }

  /// Limpiar datos al cerrar sesión
  void limpiarDatos() {
    _datos = [];
    notifyListeners();
  }
}
