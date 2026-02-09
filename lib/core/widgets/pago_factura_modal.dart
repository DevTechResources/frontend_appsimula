import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/pagos_service.dart';

/// Modal para procesar un pago/abono de factura
///
/// Uso:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => PagoFacturaModal(
///     facturaId: factura.id,
///     numeroFactura: factura.numeroFactura,
///     saldoPendiente: factura.saldoPendiente,
///     onPagoExitoso: (resultado) {
///       // Actualizar UI
///     },
///   ),
/// );
/// ```
class PagoFacturaModal extends StatefulWidget {
  final int facturaId;
  final String numeroFactura;
  final double saldoPendiente;
  final Function(ResultadoPago) onPagoExitoso;

  const PagoFacturaModal({
    Key? key,
    required this.facturaId,
    required this.numeroFactura,
    required this.saldoPendiente,
    required this.onPagoExitoso,
  }) : super(key: key);

  @override
  State<PagoFacturaModal> createState() => _PagoFacturaModalState();
}

class _PagoFacturaModalState extends State<PagoFacturaModal> {
  late TextEditingController _montoController;
  String _metodoPago = 'transferencia';
  bool _procesando = false;

  final List<Map<String, String>> _metodosPago = [
    {'valor': 'transferencia', 'label': 'Transferencia Bancaria'},
    {'valor': 'efectivo', 'label': 'Efectivo'},
    {'valor': 'tarjeta', 'label': 'Tarjeta de Crédito'},
    {'valor': 'credito', 'label': 'Crédito'},
  ];

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController(
      text: widget.saldoPendiente.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _procesarPago() async {
    final monto = double.tryParse(_montoController.text.trim());

    if (monto == null || monto <= 0) {
      _mostrarError('Ingresa un monto válido');
      return;
    }

    setState(() => _procesando = true);

    try {
      final pagosService = context.read<PagosService>();

      ResultadoPago resultado;
      if (monto < widget.saldoPendiente) {
        // Abono parcial
        resultado = await pagosService.abonarFactura(
          facturaId: widget.facturaId,
          monto: monto,
          metodoPago: _metodoPago,
        );
      } else {
        // Pago completo o excedente
        resultado = await pagosService.pagarFactura(
          facturaId: widget.facturaId,
          monto: monto,
          metodoPago: _metodoPago,
        );
      }

      if (mounted) {
        if (resultado.exito) {
          // Mostrar confirmación
          _mostrarExito(resultado);
          // Notificar al padre
          widget.onPagoExitoso(resultado);
          // Cerrar modal después de 2 segundos
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        } else {
          _mostrarError(resultado.mensaje);
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al procesar pago: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(ResultadoPago resultado) {
    final monto = double.tryParse(_montoController.text.trim()) ?? 0;
    
    String titulo = '✅ Pago Registrado';
    String mensaje = resultado.mensaje;
    
    // Personalizar mensaje según tipo de operación
    if (resultado.tipoOperacion == 'ABONO_PARCIAL') {
      titulo = '✅ Abono Registrado';
      mensaje = 'Tu valor \$${monto.toStringAsFixed(2)} se ha añadido a abonar';
    } else if (resultado.tipoOperacion == 'EXCEDENTE') {
      titulo = '✅ Pago Registrado con Excedente';
      mensaje = 'Factura pagada. Excedente: \$${resultado.excedente?.toStringAsFixed(2) ?? '0.00'}';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(mensaje),
            if (resultado.pago != null) ...[
              const SizedBox(height: 8),
              Text(
                'Número: ${resultado.pago!.numeroPago}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pagar Factura',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

              // Información de la factura
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Factura ${widget.numeroFactura}',
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
                          '\$${widget.saldoPendiente.toStringAsFixed(2)}',
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

              // Monto a pagar
              Text(
                'Monto a Pagar',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoController,
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
                  fillColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade50,
                ),
              ),

              // Información de abono
              if (_montoController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildInformacionAbono(),
                ),

              const SizedBox(height: 24),

              // Método de pago
              Text(
                'Método de Pago',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _metodoPago,
                onChanged: _procesando
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _metodoPago = value);
                        }
                      },
                items: _metodosPago
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['valor'],
                        child: Text(m['label'] ?? ''),
                      ),
                    )
                    .toList(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _procesando
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _procesando ? null : _procesarPago,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _procesando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Pagar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Aviso legal
              Text(
                '✓ Todos los datos se envían encriptados\n'
                '✓ Recibirás confirmación por correo\n'
                '✓ El cambio se refleja inmediatamente',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformacionAbono() {
    final monto = double.tryParse(_montoController.text.trim()) ?? 0;
    final diferencia = monto - widget.saldoPendiente;

    if (diferencia.abs() < 0.01) {
      // Pago exacto
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Factura será completamente pagada',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      );
    } else if (diferencia > 0) {
      // Excedente - va a anticipos
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Pago con Excedente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo pendiente: \$${(widget.saldoPendiente).toStringAsFixed(2)}\n'
              'Monto pagado: \$${monto.toStringAsFixed(2)}\n'
              'Excedente (a anticipos): \$${diferencia.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ],
        ),
      );
    } else {
      // Abono parcial
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Abono Parcial',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo pendiente: \$${(widget.saldoPendiente).toStringAsFixed(2)}\n'
              'Abonarás: \$${monto.toStringAsFixed(2)}\n'
              'Nuevo saldo: \$${(widget.saldoPendiente - monto).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],
        ),
      );
    }
  }
}
