class Pago {
  final int id;
  final int clienteId;
  final int facturaId;
  final String numeroPago;
  final double monto;
  final String metodoPago;
  final String? referenciaPasarela;
  final String estadoPago;
  final DateTime? fechaCreacion;

  Pago({
    required this.id,
    required this.clienteId,
    required this.facturaId,
    required this.numeroPago,
    required this.monto,
    required this.metodoPago,
    this.referenciaPasarela,
    required this.estadoPago,
    this.fechaCreacion,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      id: json['id_pagos'] ?? json['id'] ?? 0,
      clienteId: json['id_clientes'] ?? json['cliente_id'] ?? 0,
      facturaId: json['id_facturas'] ?? json['factura_id'] ?? 0,
      numeroPago: json['numero_pago'] ?? '',
      monto: json['monto'] != null
          ? double.parse(json['monto'].toString())
          : 0.0,
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      referenciaPasarela: json['referencia_pasarela'],
      estadoPago: json['estado_pago'] ?? 'completado',
      fechaCreacion: json['fecha_pago'] != null
          ? DateTime.parse(json['fecha_pago'])
          : (json['fecha_creacion'] != null
                ? DateTime.parse(json['fecha_creacion'])
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'factura_id': facturaId,
      'numero_pago': numeroPago,
      'monto': monto,
      'metodo_pago': metodoPago,
      'referencia_pasarela': referenciaPasarela,
      'estado_pago': estadoPago,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
    };
  }
}
