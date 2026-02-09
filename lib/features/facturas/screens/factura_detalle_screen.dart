import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../models/factura.dart';
import '../../../models/detalle_factura.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/mock_pagos_service.dart';

import '../../../core/models/resultado_pago.dart';

import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/logs/app_logger.dart';
import '../../pagos/screens/pago_tarjeta_page.dart';

class FacturaDetalleScreen extends StatefulWidget {
  final Factura factura;

  const FacturaDetalleScreen({super.key, required this.factura});

  @override
  State<FacturaDetalleScreen> createState() => _FacturaDetalleScreenState();
}

class _FacturaDetalleScreenState extends State<FacturaDetalleScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final factura = widget.factura;

    // Calcular subtotal sin IVA
    final subtotalSinIva = factura.subTotal;
    final ivaAmount = factura.iva;

    // Calcular días para vencimiento
    final ahora = DateTime.now();
    final diasParaVencimiento = (factura.fechaVencimiento ?? DateTime(2099))
        .difference(ahora)
        .inDays;
    final esVencida = diasParaVencimiento < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Factura'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado con información principal
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Número de factura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Número de Factura',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            factura.numeroFactura,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getEstadoColor(
                            factura.estado,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getEstadoColor(factura.estado),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          factura.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getEstadoColor(factura.estado),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Cliente
                  if (factura.cliente != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cliente',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          factura.cliente!.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Información de fechas
            Container(
              padding: const EdgeInsets.all(10),
              color: isDark ? const Color(0xFF252A35) : Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Fecha de emisión
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha de Emisión',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearFecha(factura.fechaEmision ?? DateTime.now()),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Fecha de vencimiento
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Fecha de Vencimiento',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearFecha(
                          factura.fechaVencimiento ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: esVencida
                              ? Colors.red
                              : const Color.fromARGB(255, 24, 161, 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Estado del vencimiento
            if (factura.fechaVencimiento != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: esVencida
                      ? Colors.red.shade50
                      : diasParaVencimiento <= 7
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: esVencida
                        ? Colors.red.shade300
                        : diasParaVencimiento <= 7
                        ? Colors.orange.shade300
                        : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      esVencida
                          ? Icons.error_outline
                          : diasParaVencimiento <= 7
                          ? Icons.warning_outlined
                          : Icons.check_circle_outline,
                      color: esVencida
                          ? Colors.red
                          : diasParaVencimiento <= 7
                          ? Colors.orange
                          : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        esVencida
                            ? 'Factura vencida hace ${-diasParaVencimiento} días'
                            : diasParaVencimiento <= 7
                            ? 'Vence en $diasParaVencimiento días'
                            : 'Factura vigente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: esVencida
                              ? Colors.red.shade700
                              : diasParaVencimiento <= 7
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Desglose de montos
            // Detalle de productos
            _buildDetalleProductos(isDark, factura),

            // Totales de la factura
            _buildTotales(isDark, factura),

            // Saldo pendiente
            /*             Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: factura.saldoPendiente > 0
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: factura.saldoPendiente > 0
                      ? Colors.red.shade300
                      : Colors.green.shade300,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Pendiente',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: factura.saldoPendiente > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (factura.saldoPendiente > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pendiente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pagado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ), */
            // Información adicional
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1C1E) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información Adicional',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildFilaInfo('Tipo de Pago', factura.tipoPago),
                  const SizedBox(height: 8),
                  _buildFilaInfo('ID de Factura', factura.id.toString()),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: widget.factura.saldoPendiente > 0
          ? FloatingActionButton.extended(
              heroTag: 'pagar_factura_${widget.factura.id}',
              onPressed: () => _mostrarDialogoPago(context),
              backgroundColor: const Color.fromARGB(255, 1, 1, 1),
              label: const Text('Pagar'),
              icon: const Icon(Icons.payment),
            )
          : null,
    );
  }

  Widget _buildDetalleProductos(bool isDark, Factura factura) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Detalle de la Factura',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Encabezado tabla
          Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'Descripción',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Cant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Precio',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Subtotal',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          const Divider(),

          // Filas - mostrar detalles reales o mensaje si no hay
          if (factura.detalles != null && factura.detalles!.isNotEmpty)
            ...factura.detalles!.map((detalle) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        detalle.descripcion,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        detalle.cantidad.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${detalle.precioUnitario.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '\$${detalle.subtotal.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(flex: 4, child: Text('Servicio facturado')),
                  const Expanded(
                    flex: 2,
                    child: Text('1', textAlign: TextAlign.center),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${factura.subTotal.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${factura.subTotal.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotales(bool isDark, Factura factura) {
    // Calcular subtotal real de los detalles si existen
    double subtotalDetalles = 0.0;
    if (factura.detalles != null && factura.detalles!.isNotEmpty) {
      subtotalDetalles = factura.detalles!.fold(
        0.0,
        (sum, detalle) => sum + detalle.subtotal,
      );
    } else {
      subtotalDetalles = factura.subTotal;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildFilaTotal('Subtotal', subtotalDetalles),
          _buildFilaTotal('IVA (15%)', factura.iva),
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

  // 💳 INICIAR PAGO CON TARJETA (abre modal Kushki simulado)
  void _iniciarPagoConTarjeta(double monto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PagoTarjetaPage(
          monto: monto,
          origen: 'detalle_factura',
          onTokenGenerado: (token) async {
            await _enviarPagoTarjetaAlBackend(token, monto);
          },
        ),
      ),
    );
  }

  // 💳 ENVIAR TOKEN AL BACKEND (aquí entra la lógica real)
  Future<void> _enviarPagoTarjetaAlBackend(String token, double monto) async {
    AppLogger.logInfo(
      '💳 Enviando pago con tarjeta al backend | Token: $token | Monto: \$${monto.toStringAsFixed(2)}',
    );

    final pagosService = MockPagosService();

    final resultado = await pagosService.pagarFactura(
      facturaId: widget.factura.id,
      monto: monto,
      metodoPago: 'tarjeta',
    );

    if (!mounted) return;

    if (resultado.exito) {
      // Refrescar datos después del pago
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);

      await facturasService.fetchFacturas(
        clienteId: authService.clienteActual?.id,
        esAdmin: authService.esInstalador,
      );
      await authService.actualizarClienteActual();

      CustomSnackBar.showPaymentSuccess(
        context,
        '✅ Pago aprobado con tarjeta | Token: $token',
      );

      AppLogger.logInfo(
        '✅ Pago con tarjeta exitoso | Factura: ${widget.factura.numeroFactura}',
      );

      setState(() {});
      Navigator.pop(context);
    } else {
      CustomOverlayNotification.showError(context, resultado.mensaje);
      AppLogger.logError('❌ Pago con tarjeta rechazado: ${resultado.mensaje}');
    }
  }

  // 💳 Mostrar diálogo de pago (igual al de facturas_tab.dart)
  void _mostrarDialogoPago(BuildContext context) {
    debugPrint(
      '🟡 [DETALLE PAGO] Mostrando diálogo de pago para factura #${widget.factura.numeroFactura}',
    );

    final montoController = TextEditingController(
      text: widget.factura.saldoPendiente.toStringAsFixed(2),
    );
    String metodoPago = 'transferencia';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pagar Factura',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factura ${widget.factura.numeroFactura}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo Pendiente:'),
                            Text(
                              '\$${widget.factura.saldoPendiente.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Monto a Pagar',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: montoController,
                    onChanged: (value) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Método de Pago',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: metodoPago,
                    onChanged: (value) => setState(() => metodoPago = value!),
                    items: const [
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferencia Bancaria'),
                      ),
                      DropdownMenuItem(
                        value: 'efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'tarjeta',
                        child: Text('Tarjeta de Crédito'),
                      ),
                    ],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final monto = double.tryParse(
                              montoController.text.trim(),
                            );
                            if (monto == null || monto <= 0) {
                              CustomOverlayNotification.showWarning(
                                context,
                                'Ingresa un monto válido',
                              );
                              return;
                            }
                            Navigator.pop(context);

                            // 💳 Si es tarjeta, abrir modal Kushki
                            if (metodoPago == 'tarjeta') {
                              _iniciarPagoConTarjeta(monto);
                            } else {
                              // Para otros métodos, mostrar confirmación
                              _mostrarConfirmacionPago(
                                widget.factura,
                                monto,
                                metodoPago,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Procesar Pago',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 💳 Mostrar confirmación de pago
  void _mostrarConfirmacionPago(
    Factura factura,
    double montoIngresado,
    String metodoPago,
  ) {
    final diferencia = montoIngresado - factura.saldoPendiente;
    late String mensajeAdvertencia, mensajeResultado;
    late IconData icono;
    late Color colorIcono;

    if (montoIngresado < factura.saldoPendiente) {
      icono = Icons.account_balance_wallet;
      colorIcono = Colors.orange;
      mensajeAdvertencia =
          'El monto ingresado es MENOR al valor total pendiente.\n\nEste valor se registrará como un ABONO PARCIAL.\n\n✅ Recibirás: "Se han abonado \$${montoIngresado.toStringAsFixed(2)} a tu cuenta"';
      mensajeResultado = 'Tu abono quedará disponible para futuras facturas.';
    } else if (diferencia > 0.01) {
      icono = Icons.check_circle;
      colorIcono = Colors.green;
      final montoPago = factura.saldoPendiente;
      final montoAbono = montoIngresado - factura.saldoPendiente;
      mensajeAdvertencia =
          'El monto ingresado es MAYOR al valor total pendiente.\n\n✅ Recibirás: "Factura pagada \$${montoPago.toStringAsFixed(2)} | Abonado a cuenta \$${montoAbono.toStringAsFixed(2)}"\n\nEl excedente se registrará como anticipos en tu cuenta.';
      mensajeResultado =
          'La factura será pagada y el sobrante disponible para futuras compras.';
    } else {
      icono = Icons.check_circle;
      colorIcono = Colors.blue;
      mensajeAdvertencia =
          'El monto ingresado coincide exactamente con el valor total pendiente.\n\n✅ Recibirás: "Factura pagada exitosamente"\n\nLa factura será cancelada en su totalidad.';
      mensajeResultado =
          'Tu deuda con esta factura será completamente saldada.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icono, color: colorIcono),
            const SizedBox(width: 8),
            const Expanded(child: Text('Confirmar Pago')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mensajeAdvertencia, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Detalle de factura:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Factura #${factura.numeroFactura}'),
                  Text(
                    '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto a procesar:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${montoIngresado.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorIcono,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorIcono.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorIcono.withOpacity(0.3)),
                ),
                child: Text(
                  mensajeResultado,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorIcono,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _procesarPago(factura, montoIngresado, metodoPago);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }

  // 💳 Procesar pago
  Future<void> _procesarPago(
    Factura factura,
    double monto,
    String metodoPago,
  ) async {
    try {
      final pagosService = MockPagosService();
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      final authService = Provider.of<AuthService>(context, listen: false);

      final resultado = await pagosService.pagarFactura(
        facturaId: factura.id,
        monto: monto,
        metodoPago: metodoPago,
      );

      if (mounted) {
        if (resultado.exito) {
          await facturasService.fetchFacturas(
            clienteId: authService.clienteActual?.id,
            esAdmin: authService.esInstalador,
          );
          await authService.actualizarClienteActual();

          final diferencia = monto - factura.saldoPendiente;
          if (monto < factura.saldoPendiente) {
            CustomSnackBar.showPaymentSuccess(
              context,
              'Se han abonado \$${monto.toStringAsFixed(2)} a tu cuenta',
            );
          } else if (diferencia > 0.01) {
            final montoPago = factura.saldoPendiente;
            final montoAbono = monto - factura.saldoPendiente;
            CustomSnackBar.showPaymentSuccess(
              context,
              '✅ Factura pagada \$${montoPago.toStringAsFixed(2)}\n✅ Abonado a cuenta \$${montoAbono.toStringAsFixed(2)}',
            );
          } else {
            CustomSnackBar.showPaymentSuccess(
              context,
              'Factura #${factura.numeroFactura} pagada exitosamente',
            );
          }

          // Actualizar la pantalla
          setState(() {});
          Navigator.pop(context);
        } else {
          CustomOverlayNotification.showError(context, resultado.mensaje);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.split('Exception:').last.trim();
        }
        CustomOverlayNotification.showError(context, errorMsg);
      }
    }
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
