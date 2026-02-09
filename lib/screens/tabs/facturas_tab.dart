import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/factura.dart';
import '../../models/pago.dart';
import '../../core/widgets/custom_overlay_notification.dart';
import '../../core/widgets/custom_snackbar.dart';
import '../../features/facturas/screens/datafast_webview_screen.dart';

class FacturasTab extends StatefulWidget {
  const FacturasTab({super.key});

  @override
  State<FacturasTab> createState() => _FacturasTabState();
}

class _FacturasTabState extends State<FacturasTab> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  List<Factura>? _facturas;
  List<Factura>? _facturasFiltradas;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFacturas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFacturas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final clienteId = authService.clienteActual?.id;

      // Si es admin (instalador), obtener TODAS las facturas
      // Si es cliente regular, filtrar solo sus facturas
      final facturas = authService.esInstalador
          ? await _apiService.getFacturas()
          : await _apiService.getFacturas(clienteId: clienteId);

      setState(() {
        _facturas = facturas;
        _facturasFiltradas = facturas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filtrarFacturas(String query) {
    if (_facturas == null) return;

    setState(() {
      if (query.isEmpty) {
        _facturasFiltradas = _facturas;
      } else {
        _facturasFiltradas = _facturas!.where((factura) {
          final numeroFactura = factura.numeroFactura.toLowerCase();
          final clienteNombre = factura.cliente?.nombre.toLowerCase() ?? '';
          final estado = factura.estado.toLowerCase();
          final busqueda = query.toLowerCase();

          return numeroFactura.contains(busqueda) ||
              clienteNombre.contains(busqueda) ||
              estado.contains(busqueda);
        }).toList();
      }
    });
  }

  void _showPagoDialog(Factura factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pagar factura - ${factura.numeroFactura}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: \$${factura.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.credit_card),
              label: const Text('Pagar con tarjeta'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                Navigator.pop(context);
                // Llama al backend para obtener los datos de Datafast
                try {
                  final resp = await _apiService.iniciarPagoDatafast(
                    factura.id,
                  );
                  if (!mounted) return;
                  final nombreProducto =
                      (factura.detalles != null && factura.detalles!.isNotEmpty)
                      ? factura.detalles!.first.descripcion
                      : 'Pago de Factura';
                  final nombreCliente = factura.cliente?.nombre ?? 'Cliente';
                  final rucCliente = factura.cliente?.ruc ?? 'N/A';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DatafastWebViewScreen(
                        url: resp['url'],
                        postData: {
                          'merchantId': resp['merchantId'],
                          'orderId': resp['orderId'],
                          'amount': resp['amount'],
                          'currency': resp['currency'],
                          'signature': resp['signature'],
                        },
                        displayData: {
                          'numeroFactura': factura.numeroFactura,
                          'monto': factura.total,
                          'metodoPago': 'datafast',
                          'fechaPago': DateTime.now().toIso8601String(),
                          'nombreProducto': nombreProducto,
                          'rucCliente': rucCliente,
                          'nombreCliente': nombreCliente,
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  CustomOverlayNotification.showError(
                    context,
                    'Error al iniciar pago: $e',
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.money),
              label: const Text('Pagar en efectivo'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: () {
                CustomOverlayNotification.showInfo(
                  context,
                  'Función en desarrollo',
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_balance),
              label: const Text('Pagar por transferencia'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: () {
                CustomOverlayNotification.showInfo(
                  context,
                  'Función en desarrollo',
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final esAdmin = authService.esInstalador;

    return Column(
      children: [
        // Buscador (solo visible para admin)
        if (esAdmin)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarFacturas,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, número de factura o estado...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarFacturas('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

        // Lista de facturas
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFacturas,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadFacturas,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _facturasFiltradas == null || _facturasFiltradas!.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? 'No se encontraron facturas'
                          : 'No hay facturas',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _facturasFiltradas!.length,
                    itemBuilder: (context, index) {
                      final factura = _facturasFiltradas![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getEstadoColor(factura.estado),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(factura.numeroFactura),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mostrar nombre del cliente si es admin
                              if (esAdmin && factura.cliente != null)
                                Text(
                                  'Cliente: ${factura.cliente!.nombre}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Text('Estado: ${factura.estado}'),
                              Text(
                                'Total: \$${factura.total.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Saldo: \$${factura.saldoPendiente.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: factura.saldoPendiente > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          trailing: factura.saldoPendiente > 0
                              ? ElevatedButton.icon(
                                  onPressed: () => _showPagoDialog(factura),
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: const Text('Pagar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                        ),
                      );
                    },
                  ),
          ),
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
      default:
        return Colors.grey;
    }
  }
}
