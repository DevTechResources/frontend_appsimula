import 'cliente.dart';
import 'detalle_factura.dart';

class Factura {
  final int id;
  final int clienteId;
  final int pedidoId;
  final String numeroFactura;
  final double subTotal;
  final double iva;
  final double descuento;
  final double total;
  final double saldoPendiente;
  final String estado;
  final String tipoPago;
  final DateTime? fechaEmision;
  final DateTime? fechaVencimiento;
  final DateTime? fechaCreacion;
  final Cliente? cliente;
  final List<DetalleFactura>? detalles;

  Factura({
    required this.id,
    required this.clienteId,
    required this.pedidoId,
    required this.numeroFactura,
    required this.subTotal,
    required this.iva,
    required this.descuento,
    required this.total,
    required this.saldoPendiente,
    required this.estado,
    required this.tipoPago,
    this.fechaEmision,
    this.fechaVencimiento,
    this.fechaCreacion,
    this.cliente,
    this.detalles,
  });

  factory Factura.fromJson(Map<String, dynamic> json) {
    return Factura(
      id: json['id_facturas'] ?? json['id'] ?? 0,
      clienteId: json['id_clientes'] ?? json['cliente_id'] ?? 0,
      pedidoId: json['id_pedidos'] ?? json['pedido_id'] ?? 0,
      numeroFactura: json['numero_factura'] ?? '',
      subTotal: json['subtotal_sin_iva'] != null
          ? double.parse(json['subtotal_sin_iva'].toString())
          : 0.0,
      iva: json['iva'] != null ? double.parse(json['iva'].toString()) : 0.0,
      descuento: json['descuento'] != null
          ? double.parse(json['descuento'].toString())
          : 0.0,
      total: json['total'] != null
          ? double.parse(json['total'].toString())
          : 0.0,
      saldoPendiente: json['saldo_pendiente'] != null
          ? double.parse(json['saldo_pendiente'].toString())
          : 0.0,
      estado: json['estado'] ?? 'pendiente',
      tipoPago: json['forma_pago'] ?? json['tipo_pago'] ?? 'efectivo',
      fechaEmision: json['fecha_emision'] != null
          ? DateTime.parse(json['fecha_emision'])
          : null,
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.parse(json['fecha_vencimiento'])
          : null,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
      cliente: json['cliente'] != null
          ? Cliente.fromJson(json['cliente'])
          : null,
      detalles: json['detalles'] != null
          ? (json['detalles'] as List)
                .map((detalle) => DetalleFactura.fromJson(detalle))
                .toList()
          : json['detalleFacturas'] != null
          ? (json['detalleFacturas'] as List)
                .map((detalle) => DetalleFactura.fromJson(detalle))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'pedido_id': pedidoId,
      'numero_factura': numeroFactura,
      'sub_total': subTotal,
      'iva': iva,
      'descuento': descuento,
      'total': total,
      'saldo_pendiente': saldoPendiente,
      'estado': estado,
      'tipo_pago': tipoPago,
      'fecha_emision': fechaEmision?.toIso8601String(),
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'fecha_creacion': fechaCreacion?.toIso8601String(),
    };
  }
}
