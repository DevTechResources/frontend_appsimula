import 'package:flutter/foundation.dart';
import '../../models/producto.dart';
import 'api_service.dart';

/// Servicio global para gestionar productos
/// Mantiene los productos en memoria y notifica cambios a todos los widgets
class ProductosService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Producto> _productos = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdate;

  // Getters
  List<Producto> get productos => List.unmodifiable(_productos);

  /// Solo productos con stock disponible (para carrito)
  List<Producto> get productosDisponibles =>
      _productos.where((p) => p.stock > 0 && p.activo).toList();

  /// Todos los productos activos (incluye sin stock para mostrar con opacidad)
  List<Producto> get productosActivos =>
      _productos.where((p) => p.activo).toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdate => _lastUpdate;

  /// Método ÚNICO para cargar TODOS los productos desde el backend
  /// SIEMPRE carga todos los productos, sin filtros
  Future<void> fetchProductos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (kDebugMode) {
      print('📡 Cargando TODOS los productos del backend...');
    }

    try {
      final productos = await _apiService.getProductos();
      _productos = productos;
      _lastUpdate = DateTime.now();
      _errorMessage = null;

      if (kDebugMode) {
        print('✅ Productos cargados: ${_productos.length} productos');
        print('📦 Productos con stock: ${productosDisponibles.length}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) {
        print('❌ Error al cargar productos: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener un producto por ID
  Producto? getProductoById(int id) {
    try {
      return _productos.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Verificar si un producto tiene stock disponible
  bool tieneStock(int productoId, {int cantidad = 1}) {
    final producto = getProductoById(productoId);
    if (producto == null) return false;
    return producto.stock >= cantidad && producto.activo;
  }

  /// Obtener el stock disponible de un producto
  int getStock(int productoId) {
    final producto = getProductoById(productoId);
    return producto?.stock ?? 0;
  }

  /// Buscar productos por nombre o descripción (incluye sin stock)
  List<Producto> buscarProductos(String query) {
    if (query.isEmpty) return productosActivos;

    final queryLower = query.toLowerCase();
    return productosActivos.where((producto) {
      final nombre = producto.nombre.toLowerCase();
      final descripcion = producto.descripcion?.toLowerCase() ?? '';
      return nombre.contains(queryLower) || descripcion.contains(queryLower);
    }).toList();
  }

  /// Limpiar todos los datos (usar al cerrar sesión)
  void clear() {
    _productos = [];
    _isLoading = false;
    _errorMessage = null;
    _lastUpdate = null;
    notifyListeners();
    if (kDebugMode) {
      print('🧽 Productos limpiados al cerrar sesión');
    }
  }

  /// Forzar actualización (útil para RefreshIndicator)
  Future<void> refresh() => fetchProductos();
}
