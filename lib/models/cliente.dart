class Cliente {
  final int id;
  final String nombre;
  final String? apellido;
  final String email;
  final String? telefono;
  final String? direccion;
  final String tipo;
  final String? empresa;
  final String? ruc;
  final bool activo;
  final DateTime? fechaCreacion;
  final String? rol;

  // 🔹 CRÉDITO
  final double cupoCredito; // cupo_credito_total
  final double saldoDisponible; // cupo_credito_disponible
  final double valorVencido;
  final double cupoUtilizado; // saldo_pendiente (BD)
  double anticipos; // 💰 Anticipos disponibles

  final int diasPlazo;

  Cliente({
    required this.id,
    required this.nombre,
    this.apellido,
    required this.email,
    this.telefono,
    this.direccion,
    required this.tipo,
    this.empresa,
    this.ruc,
    required this.activo,
    this.fechaCreacion,
    this.rol,
    this.cupoCredito = 0.0,
    this.saldoDisponible = 0.0,
    this.valorVencido = 0.0,
    this.diasPlazo = 0,
    this.cupoUtilizado = 0.0,
    this.anticipos = 0.0,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    // Función helper para parsear booleanos de varias formas
    bool _parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      if (value is int) return value != 0;
      return true; // Default a true
    }

    return Cliente(
      id: json['id_clientes'] ?? json['id'],
      nombre: json['razon_social'] ?? json['nombre'] ?? '',
      apellido: json['apellido'],
      email: json['email'] ?? '',
      telefono: json['telefono'],
      direccion: json['ciudad'] ?? json['direccion'],
      tipo: json['categoria_cliente'] ?? 'publico',
      empresa: json['empresa'],
      ruc: json['ruc'],
      activo: _parseBool(json['activo']),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
      rol: json['categoria_cliente'],

      // 🔴 CRÉDITO (LECTURA CORRECTA)
      cupoCredito:
          double.tryParse(json['cupo_credito_total']?.toString() ?? '0') ?? 0.0,
      saldoDisponible:
          double.tryParse(json['cupo_credito_disponible']?.toString() ?? '0') ??
          0.0,
      valorVencido:
          double.tryParse(json['valor_vencido']?.toString() ?? '0') ?? 0.0,
      diasPlazo: json['dias_plazo'] ?? 0,
      cupoUtilizado:
          double.tryParse(json['cupo_utilizado']?.toString() ?? '0') ?? 0.0,
      anticipos: double.tryParse(json['anticipos']?.toString() ?? '0') ?? 0.0,
    );
  }

  bool get esInstalador => rol == 'instalador';
  bool get esAdmin => rol == 'admin';
  bool get esMayorista => rol == 'mayorista';
  bool get esIntegrador => rol == 'integrador';

  /// Crea una copia del cliente con algunos campos modificados
  Cliente copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    String? direccion,
    String? tipo,
    String? empresa,
    String? ruc,
    bool? activo,
    DateTime? fechaCreacion,
    String? rol,
    double? cupoCredito,
    double? saldoDisponible,
    double? valorVencido,
    double? cupoUtilizado,
    double? anticipos,
    int? diasPlazo,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      tipo: tipo ?? this.tipo,
      empresa: empresa ?? this.empresa,
      ruc: ruc ?? this.ruc,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      rol: rol ?? this.rol,
      cupoCredito: cupoCredito ?? this.cupoCredito,
      saldoDisponible: saldoDisponible ?? this.saldoDisponible,
      valorVencido: valorVencido ?? this.valorVencido,
      cupoUtilizado: cupoUtilizado ?? this.cupoUtilizado,
      diasPlazo: diasPlazo ?? this.diasPlazo,
      anticipos: anticipos ?? this.anticipos,
    );
  }
}
