class DatosFacturacion {
  final int id;
  final int clienteId;
  final String alias;
  final String razonSocial;
  final String? empresa;
  final String rucCi;
  final String email;
  final String telefono;
  final String direccion;
  final String ciudad;
  final bool esPredeterminado;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  DatosFacturacion({
    required this.id,
    required this.clienteId,
    required this.alias,
    required this.razonSocial,
    this.empresa,
    required this.rucCi,
    required this.email,
    required this.telefono,
    required this.direccion,
    required this.ciudad,
    required this.esPredeterminado,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DatosFacturacion.fromJson(Map<String, dynamic> json) {
    return DatosFacturacion(
      id: json['id'] as int,
      clienteId: json['cliente_id'] as int,
      alias: json['alias'] as String,
      razonSocial: json['razon_social'] as String,
      empresa: json['empresa'] as String?,
      rucCi: json['ruc_ci'] as String,
      email: json['email'] as String,
      telefono: json['telefono'] as String,
      direccion: json['direccion'] as String,
      ciudad: json['ciudad'] as String,
      esPredeterminado: json['es_predeterminado'] as bool,
      activo: json['activo'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'razon_social': razonSocial,
      'empresa': empresa,
      'ruc_ci': rucCi,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'ciudad': ciudad,
      'es_predeterminado': esPredeterminado,
    };
  }

  // Para mostrar en lista
  String get displayName => alias;
  String get subtitulo => '$razonSocial - $rucCi';
}
