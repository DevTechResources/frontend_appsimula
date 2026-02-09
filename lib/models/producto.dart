class Producto {
  final int id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int stock;
  final int categoriaId;
  final String categoriaNombre;
  final String? imagen;
  final bool activo;
  final DateTime? fechaCreacion;
  

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stock,
    required this.categoriaId,
    required this.categoriaNombre,
    this.imagen,
    required this.activo,
    this.fechaCreacion,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id_productos'] ?? json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      precio: json['precio_publico'] != null
          ? double.parse(json['precio_publico'].toString())
          : (json['precio'] != null
                ? double.parse(json['precio'].toString())
                : 0.0),
      stock: json['stock'] ?? 0,
      categoriaId: json['id_categorias'] ?? json['categoria_id'] ?? 0,
      categoriaNombre: json['categoria']?['nombre'] ?? 'Sin categoría',
      imagen: json['imagen_url'] ?? json['imagen'],
      activo: json['activo'] ?? true,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
      'categoria_id': categoriaId,
      'imagen': imagen,
      'activo': activo,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
    };
  }
}
