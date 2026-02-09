import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentReceiptWidget extends StatelessWidget {
  final Map<String, dynamic> paymentData;
  final GlobalKey? repaintKey;

  const PaymentReceiptWidget({
    Key? key,
    required this.paymentData,
    this.repaintKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo y nombre empresa
                _buildHeader(),
                const SizedBox(height: 20),

                // Número de factura
                _buildInvoiceNumber(),
                const SizedBox(height: 20),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),

                // Información del pago
                _buildPaymentInfo(),
                const SizedBox(height: 20),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),

                // Detalles de la transacción
                _buildTransactionDetails(),
                const SizedBox(height: 20),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),

                // Monto total
                _buildTotalAmount(),
                const SizedBox(height: 20),

                // Estado
                _buildStatus(),
                const SizedBox(height: 30),

                // Mensaje de agradecimiento
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.business, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        // Nombre empresa
        const Text(
          'Tech Resources',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comprobante de Pago',
          style: TextStyle(
            fontSize: 14,
            color: const Color.fromARGB(255, 0, 0, 0),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceNumber() {
    final invoiceNumber = _getStringValue([
      'numeroFactura',
      'numero_factura',
      'facturaNumero',
      'factura_numero',
    ]);
    final paymentNumber = _getStringValue([
      'numeroPago',
      'numero_pago',
      'numeroPagoId',
      'id_pagos',
      'pago_id',
    ]);

    return Column(
      children: [
        _buildDetailRow(label: 'Factura #', value: invoiceNumber, isBold: true),
        const SizedBox(height: 8),
        _buildDetailRow(label: 'Pago #', value: paymentNumber, isSmall: true),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    final montoPagado = _getDoubleValue([
      'monto',
      'monto_pago',
      'total_pagado',
      'total',
      'amount',
    ]);
    final fechaPago = _getStringValue([
      'fechaPago',
      'fecha_pago',
      'fechaPagoIso',
      'created_at',
      'fecha',
    ], fallback: '');
    final metodoPago = _getStringValue([
      'metodoPago',
      'metodo_pago',
      'tipo_pago',
      'forma_pago',
      'pasarela',
    ], fallback: 'tarjeta');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INFORMACIÓN DEL PAGO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          label: 'Monto pagado',
          value: _formatCurrency(montoPagado),
        ),
        const SizedBox(height: 10),
        _buildDetailRow(label: 'Fecha de pago', value: _formatDate(fechaPago)),
        const SizedBox(height: 10),
        _buildDetailRow(
          label: 'Tipo de pago',
          value: _formatPaymentMethod(metodoPago),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails() {
    final nombreProducto = _getStringValue([
      'nombreProducto',
      'nombre_producto',
      'producto',
      'descripcion',
    ], fallback: _getFirstDetailDescription());
    final rucCliente = _getStringValue([
      'rucCliente',
      'ruc_cliente',
      'ruc',
    ], fallback: _getNestedString(['cliente'], ['ruc']) ?? 'N/A');
    final nombreCliente = _getStringValue(
      ['nombreCliente', 'nombre_cliente', 'razon_social', 'cliente'],
      fallback:
          _getNestedString(['cliente'], ['razon_social', 'nombre']) ?? 'N/A',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETALLES DE LA FACTURA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailRow(label: 'Producto/Servicio', value: nombreProducto),
        const SizedBox(height: 10),
        _buildDetailRow(label: 'RUC Cliente', value: rucCliente),
        const SizedBox(height: 10),
        _buildDetailRow(label: 'Cliente', value: nombreCliente),
      ],
    );
  }

  Widget _buildTotalAmount() {
    final monto = _getDoubleValue([
      'monto',
      'monto_pago',
      'total_pagado',
      'total',
      'amount',
    ]);
    final montoFormato = _formatCurrency(monto);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'MONTO PAGADO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            montoFormato,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final estado = _getStringValue([
      'estado',
      'estado_pago',
      'status',
    ], fallback: 'completado');
    final isCompleted =
        estado.toLowerCase() == 'completado' ||
        estado.toLowerCase() == 'approved' ||
        estado.toLowerCase() == 'paid';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.pending,
          color: isCompleted ? Colors.green : Colors.orange,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          isCompleted ? 'Pago Completado' : 'Pago en Proceso',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCompleted ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '¡Gracias por su pago!',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Este comprobante es válido como constancia de pago',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tech Resources © 2026',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isSmall = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 11 : 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 11 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(dynamic amount) {
    try {
      final value = amount is String
          ? double.parse(amount)
          : (amount as num).toDouble();
      final formatter = NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 2,
        locale: 'es_EC',
      );
      return formatter.format(value);
    } catch (e) {
      return '\$ 0.00';
    }
  }

  String _formatDate(dynamic date) {
    try {
      DateTime parsedDate;
      if (date is String) {
        parsedDate = DateTime.parse(date);
      } else if (date is DateTime) {
        parsedDate = date;
      } else {
        return 'Hoy';
      }

      final formatter = DateFormat('dd/MM/yyyy HH:mm', 'es_EC');
      return formatter.format(parsedDate);
    } catch (e) {
      return 'Hoy';
    }
  }

  String _formatPaymentMethod(String method) {
    final methodMap = {
      'tarjeta': 'Tarjeta de Crédito/Débito',
      'transferencia': 'Transferencia Bancaria',
      'efectivo': 'Efectivo',
      'cheque': 'Cheque',
      'datafast': 'Tarjeta (Datafast)',
    };

    return methodMap[method.toLowerCase()] ?? 'Método no especificado';
  }

  String _getStringValue(List<String> keys, {String fallback = 'N/A'}) {
    for (final key in keys) {
      final value = paymentData[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }

  double _getDoubleValue(List<String> keys) {
    for (final key in keys) {
      final value = paymentData[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  String? _getNestedString(List<String> parentKeys, List<String> keys) {
    for (final parentKey in parentKeys) {
      final parent = paymentData[parentKey];
      if (parent is Map<String, dynamic>) {
        for (final key in keys) {
          final value = parent[key];
          if (value != null) {
            final text = value.toString().trim();
            if (text.isNotEmpty) return text;
          }
        }
      }
    }
    return null;
  }

  String _getFirstDetailDescription() {
    final detailsCandidates = [
      paymentData['detalleFacturas'],
      paymentData['detalles'],
      paymentData['detalle_facturas'],
      paymentData['detalle_factura'],
    ];

    for (final candidate in detailsCandidates) {
      if (candidate is List && candidate.isNotEmpty) {
        final first = candidate.first;
        if (first is Map<String, dynamic>) {
          final desc = first['descripcion'] ?? first['nombre'];
          if (desc != null && desc.toString().trim().isNotEmpty) {
            return desc.toString();
          }
        } else if (first != null) {
          final text = first.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }

    return 'Servicio';
  }
}
