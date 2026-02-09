import 'producto.dart';

class CarritoItem {
  final Producto producto;
  int cantidad;

  CarritoItem({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;

  Map<String, dynamic> toJson() {
    return {
      'id_productos': producto.id,
      'nombre': producto.nombre,
      'precio': producto.precio,
      'cantidad': cantidad,
      'subtotal': subtotal,
    };
  }
}
