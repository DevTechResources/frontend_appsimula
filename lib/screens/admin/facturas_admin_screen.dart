import 'package:flutter/material.dart';
import '../../models/factura.dart';
import '../../core/services/api_service.dart';
import '../../core/services/navigation_service.dart';

class FacturasAdminScreen extends StatefulWidget {
  const FacturasAdminScreen({super.key});

  @override
  State<FacturasAdminScreen> createState() => _FacturasAdminScreenState();
}

class _FacturasAdminScreenState extends State<FacturasAdminScreen>
    with RouteAware {
  final ApiService _apiService = ApiService();
  List<Factura>? _facturas;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      routeObserver.subscribe(this, modalRoute);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Facturas'),
        actions: [
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
                            _buildInfoRow(
                              'Saldo Pendiente',
                              '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                              valueColor: factura.saldoPendiente > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
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

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    // Se llamó cuando la ruta fue empujada - refrescar
    _cargarFacturas();
  }

  @override
  void didPopNext() {
    // Se volvió a esta ruta desde otra (p. ej. al cerrar detalle) - refrescar
    _cargarFacturas();
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
