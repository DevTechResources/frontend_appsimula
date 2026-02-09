import 'package:flutter/foundation.dart';
import '../../models/carrito_item.dart';
import '../../models/producto.dart';
import 'api_service.dart';

class CarritoService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<CarritoItem> _items = [];
  bool _isLoading = false;

  List<CarritoItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  int get cantidadTotal => _items.fold(0, (sum, item) => sum + item.cantidad);

  double get total => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Cargar carrito desde el backend
  Future<void> fetchCarrito() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.get('/carrito');

      if (response['success']) {
        final List<dynamic> data = response['data'];
        _items.clear();

        for (var item in data) {
          final producto = Producto.fromJson(item['producto']);
          final cantidad = item['cantidad'] as int;
          _items.add(CarritoItem(producto: producto, cantidad: cantidad));
        }

        if (kDebugMode) {
          print('✅ Carrito cargado desde BD: ${_items.length} items');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al cargar carrito: $e');
      }
      _items.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agregar producto al carrito con validación de stock y sincronización con BD
  Future<bool> agregarProducto(Producto producto, {int cantidad = 1}) async {
    // 🔥 VALIDACIÓN DE STOCK CRÍTICA
    if (producto.stock < cantidad) {
      if (kDebugMode) {
        print(
          '❌ Stock insuficiente para ${producto.nombre}. Disponible: ${producto.stock}, Solicitado: $cantidad',
        );
      }
      return false;
    }

    if (!producto.activo) {
      if (kDebugMode) {
        print('❌ Producto inactivo: ${producto.nombre}');
      }
      return false;
    }

    final index = _items.indexWhere((item) => item.producto.id == producto.id);

    if (index >= 0) {
      final nuevaCantidad = _items[index].cantidad + cantidad;

      // Validar que no exceda el stock disponible
      if (nuevaCantidad > producto.stock) {
        if (kDebugMode) {
          print(
            '❌ No hay suficiente stock. Disponible: ${producto.stock}, En carrito: ${_items[index].cantidad}, Intentando agregar: $cantidad',
          );
        }
        return false;
      }

      _items[index].cantidad = nuevaCantidad;
    } else {
      _items.add(CarritoItem(producto: producto, cantidad: cantidad));
    }

    // Sincronizar con backend
    await _sincronizarConBackend(
      producto.id,
      index >= 0 ? _items[index].cantidad : cantidad,
      producto.precio,
    );

    notifyListeners();
    if (kDebugMode) {
      print(
        '✅ Producto agregado al carrito: ${producto.nombre} x$cantidad (Stock disponible: ${producto.stock})',
      );
    }
    return true;
  }

  /// Actualizar cantidad en carrito y BD
  Future<void> actualizarCantidad(int productoId, int nuevaCantidad) async {
    final index = _items.indexWhere((item) => item.producto.id == productoId);

    if (index >= 0) {
      if (nuevaCantidad <= 0) {
        // Eliminar del carrito
        await eliminarItem(productoId);
      } else {
        _items[index].cantidad = nuevaCantidad;
        // Sincronizar con backend
        await _sincronizarConBackend(
          productoId,
          nuevaCantidad,
          _items[index].producto.precio,
        );
        notifyListeners();
      }
    }
  }

  /// Eliminar item del carrito y BD
  Future<void> eliminarItem(int productoId) async {
    _items.removeWhere((item) => item.producto.id == productoId);

    // Eliminar del backend
    try {
      await _apiService.delete('/carrito/$productoId');
      if (kDebugMode) {
        print('✅ Item eliminado del carrito en BD');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al eliminar item de BD: $e');
      }
    }

    notifyListeners();
  }

  /// Vaciar carrito local y BD
  Future<void> vaciarCarrito() async {
    _items.clear();

    // Limpiar en backend
    try {
      await _apiService.delete('/carrito');
      if (kDebugMode) {
        print('✅ Carrito vaciado en BD');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al vaciar carrito en BD: $e');
      }
    }

    notifyListeners();
  }

  /// Sincronizar item con el backend
  Future<void> _sincronizarConBackend(
    int productoId,
    int cantidad,
    double precio,
  ) async {
    try {
      await _apiService.post('/carrito', {
        'productoId': productoId,
        'cantidad': cantidad,
        'precio': precio,
      });
      if (kDebugMode) {
        print('✅ Carrito sincronizado con BD');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al sincronizar con BD: $e');
      }
    }
  }

  int obtenerCantidadProducto(int productoId) {
    final item = _items.firstWhere(
      (item) => item.producto.id == productoId,
      orElse: () => CarritoItem(
        producto: Producto(
          id: 0,
          nombre: '',
          precio: 0,
          stock: 0,
          categoriaId: 0,
          categoriaNombre: 'Sin categoría',
          activo: false,
        ),
        cantidad: 0,
      ),
    );
    return item.cantidad;
  }

  /// Limpiar carrito local al cerrar sesión (sin tocar BD)
  void limpiarCarritoLocal() {
    _items.clear();
    notifyListeners();
  }
}
