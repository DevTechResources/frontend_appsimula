class ReceiptData {
  final String numeroFactura;
  final String numeroPago;
  final double monto;
  final String metodoPago;
  final DateTime fechaPago;
  final String nombreProducto;
  final String rucCliente;
  final String nombreCliente;
  final String estado;

  ReceiptData({
    required this.numeroFactura,
    required this.numeroPago,
    required this.monto,
    required this.metodoPago,
    required this.fechaPago,
    required this.nombreProducto,
    required this.rucCliente,
    required this.nombreCliente,
    this.estado = 'completado',
  });

  /// Convierte a Map para pasar como parámetro
  Map<String, dynamic> toMap() {
    return {
      'numeroFactura': numeroFactura,
      'numeroPago': numeroPago,
      'monto': monto,
      'metodoPago': metodoPago,
      'fechaPago': fechaPago.toIso8601String(),
      'nombreProducto': nombreProducto,
      'rucCliente': rucCliente,
      'nombreCliente': nombreCliente,
      'estado': estado,
    };
  }

  /// Crea desde un Map
  factory ReceiptData.fromMap(Map<String, dynamic> map) {
    return ReceiptData(
      numeroFactura: map['numeroFactura'] ?? '',
      numeroPago: map['numeroPago'] ?? '',
      monto: (map['monto'] ?? 0.0).toDouble(),
      metodoPago: map['metodoPago'] ?? 'tarjeta',
      fechaPago: map['fechaPago'] is String
          ? DateTime.parse(map['fechaPago'])
          : (map['fechaPago'] ?? DateTime.now()),
      nombreProducto: map['nombreProducto'] ?? 'Servicio',
      rucCliente: map['rucCliente'] ?? 'N/A',
      nombreCliente: map['nombreCliente'] ?? 'Cliente',
      estado: map['estado'] ?? 'completado',
    );
  }
}
