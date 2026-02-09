class Pedido {
  final int id;
  final int clienteId;
  final String numeroPedido;
  final double subTotal;
  final double iva;
  final double descuento;
  final double total;
  final String tipoPago;
  final String estado;
  final String? direccionEnvio;
  final DateTime? fechaCreacion;

  Pedido({
    required this.id,
    required this.clienteId,
    required this.numeroPedido,
    required this.subTotal,
    required this.iva,
    required this.descuento,
    required this.total,
    required this.tipoPago,
    required this.estado,
    this.direccionEnvio,
    this.fechaCreacion,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['id_pedidos'] ?? json['id'] ?? 0,
      clienteId: json['id_clientes'] ?? json['cliente_id'] ?? 0,
      numeroPedido: json['numero_pedido'] ?? '',
      subTotal: json['sub_total'] != null
          ? double.parse(json['sub_total'].toString())
          : 0.0,
      iva: json['iva'] != null ? double.parse(json['iva'].toString()) : 0.0,
      descuento: json['descuento'] != null
          ? double.parse(json['descuento'].toString())
          : 0.0,
      total: json['total'] != null
          ? double.parse(json['total'].toString())
          : 0.0,
      tipoPago: json['tipo_pago'] ?? 'efectivo',
      estado: json['estado'] ?? 'pendiente',
      direccionEnvio: json['direccion_envio'],
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'numero_pedido': numeroPedido,
      'sub_total': subTotal,
      'iva': iva,
      'descuento': descuento,
      'total': total,
      'tipo_pago': tipoPago,
      'estado': estado,
      'direccion_envio': direccionEnvio,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
    };
  }
}
