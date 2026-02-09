class DetalleFactura {
  final int id;
  final int facturaId;
  final int productoId;
  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  DetalleFactura({
    required this.id,
    required this.facturaId,
    required this.productoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory DetalleFactura.fromJson(Map<String, dynamic> json) {
    // Parsear cantidad
    double cantidad = 0.0;
    if (json['cantidad'] != null) {
      try {
        cantidad = double.parse(json['cantidad'].toString());
      } catch (e) {
        cantidad = 0.0;
      }
    }

    // Parsear precio unitario
    double precioUnitario = 0.0;
    if (json['precio_unitario'] != null) {
      try {
        precioUnitario = double.parse(json['precio_unitario'].toString());
      } catch (e) {
        precioUnitario = 0.0;
      }
    } else if (json['precio'] != null) {
      try {
        precioUnitario = double.parse(json['precio'].toString());
      } catch (e) {
        precioUnitario = 0.0;
      }
    }

    // Parsear subtotal o calcularlo
    double subtotal = 0.0;
    if (json['subtotal'] != null) {
      try {
        subtotal = double.parse(json['subtotal'].toString());
      } catch (e) {
        subtotal = cantidad * precioUnitario;
      }
    } else {
      subtotal = cantidad * precioUnitario;
    }

    return DetalleFactura(
      id: json['id_detalle_facturas'] ?? json['id'] ?? 0,
      facturaId: json['id_facturas'] ?? json['factura_id'] ?? 0,
      productoId: json['id_productos'] ?? json['producto_id'] ?? 0,
      descripcion:
          json['producto']?['nombre'] ??
          json['descripcion'] ??
          json['nombre_producto'] ??
          '',
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      subtotal: subtotal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factura_id': facturaId,
      'producto_id': productoId,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }
}
