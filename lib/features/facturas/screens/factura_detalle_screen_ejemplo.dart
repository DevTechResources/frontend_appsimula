// EJEMPLO DE INTEGRACIÓN DE PAGOS EN FacturaDetalleScreen
// Este archivo muestra cómo integrar la modal de pago y el servicio PagosService

import 'package:flutter/material.dart';
import '../../../models/factura.dart';
import '../../../core/widgets/pago_factura_modal.dart'; // ← NUEVO: Importar modal
import '../../../core/services/pagos_service.dart'; // ← NUEVO: Importar servicio

class FacturaDetalleScreenConPagos extends StatefulWidget {
  final Factura factura;

  const FacturaDetalleScreenConPagos({Key? key, required this.factura})
    : super(key: key);

  @override
  State<FacturaDetalleScreenConPagos> createState() =>
      _FacturaDetalleScreenConPagosState();
}

class _FacturaDetalleScreenConPagosState
    extends State<FacturaDetalleScreenConPagos> {
  late Factura factura;

  @override
  void initState() {
    super.initState();
    factura = widget.factura;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Factura'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEncabezado(isDark),
            _buildProductos(isDark),
            _buildTotales(isDark),
            _buildInfoPago(isDark),

            // ← NUEVO: Botón de pago
            if (factura.saldoPendiente > 0) _buildBotonPagar(context, isDark),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ← NUEVO: Método para construir el botón de pago
  Widget _buildBotonPagar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _abrirModalPago(context),
          icon: const Icon(Icons.payment),
          label: const Text('Pagar Factura'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  // ← NUEVO: Método para abrir la modal de pago
  void _abrirModalPago(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PagoFacturaModal(
        facturaId: factura.id,
        numeroFactura: factura.numeroFactura,
        saldoPendiente: factura.saldoPendiente,
        onPagoExitoso: (ResultadoPago resultado) {
          // Actualizar el estado local con la factura actualizada
          setState(() {
            if (resultado.facturaActualizada != null) {
              factura = resultado.facturaActualizada!;
            }
          });

          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado.mensaje),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // ← OPCIONAL: Refrescar la lista de facturas en segundo plano
          _refrescarFacturas(context);
        },
      ),
    );
  }

  // ← OPCIONAL: Refrescar la lista de facturas después del pago
  void _refrescarFacturas(BuildContext context) {
    // Obtener el FacturasService del Provider
    // (No usado en este ejemplo, pero disponible para expandir)
    // final facturasService = Provider.of<FacturasService>(context, listen: false);

    // Refrescar sin bloquear el UI
    Future.microtask(() {
      try {
        // Simulamos que el servicio cargará facturas después del pago
        // En una app real, esto se haría desde PagosService
        print('Facturas recargarían desde cargarFacturas()');
      } catch (e) {
        print('Error: $e');
      }
    });
  }

  // RESTO DE MÉTODOS (igual que en la pantalla original)

  Widget _buildEncabezado(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factura #${factura.numeroFactura}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha: ${_formatearFecha(factura.fechaEmision ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getEstadoColor(factura.estado),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  factura.estado.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPago(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de Pago',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFilaInfo(
            'Saldo Pendiente',
            '\$${factura.saldoPendiente.toStringAsFixed(2)}',
          ),
          _buildFilaInfo('Método de Pago', factura.tipoPago),
        ],
      ),
    );
  }

  Widget _buildProductos(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos/Servicios',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Ver detalles del pedido #${factura.pedidoId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotales(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildFilaTotal('Subtotal', factura.subTotal),
          _buildFilaTotal('Descuento', factura.descuento),
          _buildFilaTotal('IVA', factura.iva),
          const Divider(),
          _buildFilaTotal('TOTAL', factura.total, esTotal: true),
        ],
      ),
    );
  }

  Widget _buildFilaTotal(String label, double valor, {bool esTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: esTotal ? 14 : 12,
              fontWeight: esTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: esTotal ? 16 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaInfo(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          valor,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'emitida':
        return Colors.orange;
      case 'pagada':
        return Colors.green;
      case 'anulada':
        return Colors.red;
      case 'pendiente':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
