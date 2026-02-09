class Categoria {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? imageUrl;
  final int orden;
  final bool activo;

  Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.imageUrl,
    this.orden = 0,
    this.activo = true,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id_categorias'] ?? json['id'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      imageUrl: json['image_url'],
      orden: json['orden'] ?? 0,
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_categorias': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'image_url': imageUrl,
      'orden': orden,
      'activo': activo,
    };
  }
}
