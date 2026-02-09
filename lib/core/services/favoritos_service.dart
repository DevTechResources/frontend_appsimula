import 'package:flutter/material.dart';
import '../../models/producto.dart';
import 'api_service.dart';

class FavoritosService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Producto> _favoritos = [];
  bool _isLoading = false;

  List<Producto> get favoritos => _favoritos;
  bool get isLoading => _isLoading;
  int get cantidadFavoritos => _favoritos.length;

  /// Verifica si un producto está en favoritos
  bool esFavorito(int productoId) {
    return _favoritos.any((p) => p.id == productoId);
  }

  /// Cargar favoritos desde el backend
  Future<void> fetchFavoritos() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.get('/favoritos');

      if (response['success']) {
        final List<dynamic> data = response['data'];
        _favoritos = data
            .map((item) => Producto.fromJson(item['producto']))
            .toList();

        print('✅ Favoritos cargados: ${_favoritos.length}');
      }
    } catch (e) {
      print('❌ Error al cargar favoritos: $e');
      _favoritos = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agregar producto a favoritos
  Future<bool> agregarFavorito(Producto producto) async {
    try {
      final response = await _apiService.post('/favoritos', {
        'productoId': producto.id,
      });

      if (response['success']) {
        if (!esFavorito(producto.id)) {
          _favoritos.add(producto);
          notifyListeners();
        }
        print('✅ Favorito agregado: ${producto.nombre}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al agregar favorito: $e');
      return false;
    }
  }

  /// Eliminar producto de favoritos
  Future<bool> eliminarFavorito(int productoId) async {
    try {
      final response = await _apiService.delete('/favoritos/$productoId');

      if (response['success']) {
        _favoritos.removeWhere((p) => p.id == productoId);
        notifyListeners();
        print('✅ Favorito eliminado: ID $productoId');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error al eliminar favorito: $e');
      return false;
    }
  }

  /// Toggle favorito (agregar o eliminar)
  Future<bool> toggleFavorito(Producto producto) async {
    if (esFavorito(producto.id)) {
      return await eliminarFavorito(producto.id);
    } else {
      return await agregarFavorito(producto);
    }
  }

  /// Limpiar favoritos al cerrar sesión (solo estado local, NO elimina de BD)
  void limpiarFavoritosLocal() {
    _favoritos = [];
    notifyListeners();
  }
}
