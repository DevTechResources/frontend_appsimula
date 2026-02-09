import 'package:flutter/foundation.dart';
import '../../models/factura.dart';
import 'api_service.dart';

/// Servicio global para gestionar facturas
/// Mantiene las facturas en memoria y notifica cambios a todos los widgets
class FacturasService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Factura> _facturas = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdate;

  // Getters
  List<Factura> get facturas => List.unmodifiable(_facturas);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdate => _lastUpdate;

  /// Facturas pendientes
  List<Factura> get facturasPendientes =>
      _facturas.where((f) => f.estado == 'pendiente').toList();

  /// Facturas pagadas
  List<Factura> get facturasPagadas =>
      _facturas.where((f) => f.estado == 'pagado').toList();

  /// Método ÚNICO para cargar facturas desde el backend
  /// Este es el método que debe llamarse después de cada operación crítica
  Future<void> fetchFacturas({int? clienteId, bool esAdmin = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Si es admin, obtener todas las facturas, sino filtrar por cliente
      final facturas = esAdmin
          ? await _apiService.getFacturas()
          : await _apiService.getFacturas(clienteId: clienteId);

      _facturas = facturas;
      _lastUpdate = DateTime.now();
      _errorMessage = null;

      if (kDebugMode) {
        print('✅ Facturas actualizadas: ${_facturas.length} facturas');
        print('📋 Pendientes: ${facturasPendientes.length}');
        print('✔️ Pagadas: ${facturasPagadas.length}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) {
        print('❌ Error al cargar facturas: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener una factura por ID
  Factura? getFacturaById(int id) {
    try {
      return _facturas.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Buscar facturas por número, cliente o estado
  List<Factura> buscarFacturas(String query) {
    if (query.isEmpty) return facturas;

    final queryLower = query.toLowerCase();
    return facturas.where((factura) {
      final numeroFactura = factura.numeroFactura.toLowerCase();
      final clienteNombre = factura.cliente?.nombre.toLowerCase() ?? '';
      final estado = factura.estado.toLowerCase();
      return numeroFactura.contains(queryLower) ||
          clienteNombre.contains(queryLower) ||
          estado.contains(queryLower);
    }).toList();
  }

  /// Limpiar todos los datos (usar al cerrar sesión)
  void clear() {
    _facturas = [];
    _isLoading = false;
    _errorMessage = null;
    _lastUpdate = null;
    notifyListeners();
    if (kDebugMode) {
      print('🧽 Facturas limpiadas al cerrar sesión');
    }
  }

  /// Forzar actualización (útil para RefreshIndicator)
  Future<void> refresh({int? clienteId, bool esAdmin = false}) =>
      fetchFacturas(clienteId: clienteId, esAdmin: esAdmin);

  /// Llamar cuando las facturas cambien (legacy - para compatibilidad)
  void notifyUpdated() {
    notifyListeners();
  }
}
