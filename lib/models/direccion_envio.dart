class DireccionEnvio {
  final int id;
  final int clienteId;
  final String alias;
  final String? direccionMatriz;
  final String? direccionSucursal;
  final String telefono;
  final String ciudad;
  final String provincia;
  final String? codigoPostal;
  final String? detallesAdicionales;
  final bool esPredeterminada;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  DireccionEnvio({
    required this.id,
    required this.clienteId,
    required this.alias,
    this.direccionMatriz,
    this.direccionSucursal,
    required this.telefono,
    required this.ciudad,
    required this.provincia,
    this.codigoPostal,
    this.detallesAdicionales,
    required this.esPredeterminada,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DireccionEnvio.fromJson(Map<String, dynamic> json) {
    return DireccionEnvio(
      id: json['id'] as int,
      clienteId: json['cliente_id'] as int,
      alias: json['alias'] as String,
      direccionMatriz: json['direccion_matriz'] as String?,
      direccionSucursal: json['direccion_sucursal'] as String?,
      telefono: json['telefono'] as String,
      ciudad: json['ciudad'] as String,
      provincia: json['provincia'] as String,
      codigoPostal: json['codigo_postal'] as String?,
      detallesAdicionales: json['detalles_adicionales'] as String?,
      esPredeterminada: json['es_predeterminada'] as bool,
      activo: json['activo'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'direccion_matriz': direccionMatriz,
      'direccion_sucursal': direccionSucursal,
      'telefono': telefono,
      'ciudad': ciudad,
      'provincia': provincia,
      'codigo_postal': codigoPostal,
      'detalles_adicionales': detallesAdicionales,
      'es_predeterminada': esPredeterminada,
    };
  }

  // Para mostrar en lista
  String get displayName => alias;
  String get direccionCompleta {
    final partes = <String>[];
    if (direccionMatriz != null && direccionMatriz!.isNotEmpty) {
      partes.add(direccionMatriz!);
    }
    if (direccionSucursal != null && direccionSucursal!.isNotEmpty) {
      partes.add(direccionSucursal!);
    }
    return partes.join(', ');
  }

  String get subtitulo => '$direccionCompleta - $ciudad, $provincia';
}
