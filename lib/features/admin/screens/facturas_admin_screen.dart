import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/factura.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';

class FacturasAdminScreen extends StatefulWidget {
  const FacturasAdminScreen({super.key});

  @override
  State<FacturasAdminScreen> createState() => _FacturasAdminScreenState();
}

class _FacturasAdminScreenState extends State<FacturasAdminScreen> {
  final ApiService _apiService = ApiService();
  List<Factura>? _facturas;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
    // Suscribirse a notificaciones de cambios en facturas
    try {
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      facturasService.addListener(_onFacturasUpdated);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      facturasService.removeListener(_onFacturasUpdated);
    } catch (_) {}
    super.dispose();
  }

  void _onFacturasUpdated() {
    // Recargar listados cuando alguien notifique cambios (ej. pago)
    if (mounted) _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final facturas = await _apiService.obtenerFacturas();
      setState(() {
        _facturas = facturas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagada':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'vencida':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _mostrarDialogoIVA() async {
    final ivaActual = await _apiService.obtenerIVA();
    final controller = TextEditingController(text: ivaActual.toString());

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.percent, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Configurar IVA'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración Universal de IVA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este cambio afectará a TODOS los productos que tengan IVA activado.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Porcentaje de IVA (%)',
                hintText: 'Ej: 15',
                prefixIcon: const Icon(Icons.percent),
                border: const OutlineInputBorder(),
                helperText: 'IVA actual: $ivaActual%',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se aplicará en todos los pedidos y facturas futuros',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final valor = double.tryParse(controller.text);
              if (valor == null || valor < 0 || valor > 100) {
                CustomOverlayNotification.showError(
                  context,
                  'Ingrese un porcentaje válido entre 0 y 100',
                );
                return;
              }

              try {
                await _apiService.actualizarIVA(valor);
                if (mounted) {
                  Navigator.pop(context);
                  CustomOverlayNotification.showSuccess(
                    context,
                    'IVA actualizado a $valor% correctamente',
                  );
                }
              } catch (e) {
                if (mounted) {
                  CustomOverlayNotification.showError(
                    context,
                    'Error al actualizar IVA: ${e.toString()}',
                  );
                }
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Facturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar IVA',
            onPressed: _mostrarDialogoIVA,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarFacturas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarFacturas,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _facturas!.isEmpty
          ? const Center(child: Text('No hay facturas registradas'))
          : ListView.builder(
              itemCount: _facturas!.length,
              itemBuilder: (context, index) {
                final factura = _facturas![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.receipt_long,
                      color: _getEstadoColor(factura.estado),
                    ),
                    title: Text(
                      'Factura ${factura.numeroFactura}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Total: \$${factura.total.toStringAsFixed(2)} - ${factura.estado}',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Cliente',
                              'ID: ${factura.clienteId}',
                            ),
                            _buildInfoRow(
                              'Fecha Emisión',
                              factura.fechaEmision != null
                                  ? _formatearFecha(factura.fechaEmision!)
                                  : 'N/A',
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Subtotal',
                              '\$${factura.subTotal.toStringAsFixed(2)}',
                            ),
                            _buildInfoRow(
                              'IVA',
                              '\$${factura.iva.toStringAsFixed(2)}',
                            ),
                            _buildInfoRow(
                              'Descuento',
                              '\$${factura.descuento.toStringAsFixed(2)}',
                            ),
                            _buildInfoRow(
                              'TOTAL',
                              '\$${factura.total.toStringAsFixed(2)}',
                              isBold: true,
                            ),
/*                             _buildInfoRow(
                              'Saldo Pendiente',
                              '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                              valueColor: factura.saldoPendiente > 0
                                  ? Colors.red
                                  : Colors.green,
                            ), */
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    // TODO: Implementar edición
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Función en desarrollo'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    // TODO: Implementar vista detallada
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Función en desarrollo'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Ver Detalle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar creación de factura
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Función en desarrollo')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}
