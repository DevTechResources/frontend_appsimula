import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/widgets/custom_confirm_dialog.dart';
import 'datos_facturacion_form_screen.dart';

class DatosFacturacionScreen extends StatefulWidget {
  const DatosFacturacionScreen({super.key});

  @override
  State<DatosFacturacionScreen> createState() => _DatosFacturacionScreenState();
}

class _DatosFacturacionScreenState extends State<DatosFacturacionScreen> {
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final service = Provider.of<DatosFacturacionService>(
      context,
      listen: false,
    );
    await service.fetchDatos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos de Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navegarAFormulario(null),
            tooltip: 'Agregar datos',
          ),
        ],
      ),
      body: Consumer<DatosFacturacionService>(
        builder: (context, service, child) {
          if (service.datos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes datos de facturación',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega tus datos para facilitar tus compras',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navegarAFormulario(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Datos'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _cargarDatos,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.datos.length,
              itemBuilder: (context, index) {
                final dato = service.datos[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _navegarAFormulario(dato.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.receipt,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dato.alias,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dato.razonSocial,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (dato.esPredeterminado)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Default',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(Icons.badge, 'RUC/CI', dato.rucCi),
                          const SizedBox(height: 8),
                          if (dato.empresa != null)
                            _buildInfoRow(
                              Icons.business,
                              'Empresa',
                              dato.empresa!,
                            ),
                          if (dato.empresa != null) const SizedBox(height: 8),
                          _buildInfoRow(Icons.email, 'Email', dato.email),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.phone, 'Teléfono', dato.telefono),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_on,
                            'Dirección',
                            dato.direccion,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_city,
                            'Ciudad',
                            dato.ciudad,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (!dato.esPredeterminado)
                                TextButton.icon(
                                  onPressed: () =>
                                      _establecerPredeterminado(dato.id),
                                  icon: const Icon(Icons.star_border, size: 18),
                                  label: const Text(
                                    'Predeterminado',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: () => _navegarAFormulario(dato.id),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text(
                                  'Editar',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmarEliminar(dato.id, dato.alias),
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navegarAFormulario(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Future<void> _navegarAFormulario(int? id) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DatosFacturacionFormScreen(datoId: id),
      ),
    );

    if (resultado == true) {
      _cargarDatos();
    }
  }

  Future<void> _establecerPredeterminado(int id) async {
    final service = Provider.of<DatosFacturacionService>(
      context,
      listen: false,
    );
    final exito = await service.establecerPredeterminado(id);

    if (mounted) {
      if (exito) {
        CustomOverlayNotification.showSuccess(
          context,
          'Datos establecidos como predeterminados',
        );
      } else {
        CustomOverlayNotification.showError(
          context,
          'Error al establecer predeterminado',
        );
      }
    }
  }

  Future<void> _confirmarEliminar(int id, String alias) async {
    final confirmar = await CustomConfirmDialog.showDelete(
      context,
      itemName: alias,
      type: 'datos de facturación',
    );

    if (confirmar && mounted) {
      final service = Provider.of<DatosFacturacionService>(
        context,
        listen: false,
      );
      final exito = await service.eliminar(id);

      if (mounted) {
        if (exito) {
          CustomOverlayNotification.showSuccess(
            context,
            'Datos eliminados exitosamente',
          );
        } else {
          CustomOverlayNotification.showError(
            context,
            'Error al eliminar datos',
          );
        }
      }
    }
  }
}
