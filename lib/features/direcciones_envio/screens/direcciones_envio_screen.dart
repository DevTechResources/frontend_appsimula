import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/widgets/custom_confirm_dialog.dart';
import 'direccion_envio_form_screen.dart';

class DireccionesEnvioScreen extends StatefulWidget {
  const DireccionesEnvioScreen({super.key});

  @override
  State<DireccionesEnvioScreen> createState() => _DireccionesEnvioScreenState();
}

class _DireccionesEnvioScreenState extends State<DireccionesEnvioScreen> {
  @override
  void initState() {
    super.initState();
    _cargarDirecciones();
  }

  Future<void> _cargarDirecciones() async {
    final service = Provider.of<DireccionesEnvioService>(
      context,
      listen: false,
    );
    await service.fetchDirecciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direcciones de Envío'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navegarAFormulario(null),
            tooltip: 'Agregar dirección',
          ),
        ],
      ),
      body: Consumer<DireccionesEnvioService>(
        builder: (context, service, child) {
          if (service.direcciones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 100, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes direcciones guardadas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega direcciones para facilitar tus envíos',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navegarAFormulario(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Dirección'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _cargarDirecciones,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.direcciones.length,
              itemBuilder: (context, index) {
                final direccion = service.direcciones[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _navegarAFormulario(direccion.id),
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
                                      Icons.location_on,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            direccion.alias,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${direccion.ciudad}, ${direccion.provincia}',
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
                              if (direccion.esPredeterminada)
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
                          if (direccion.direccionMatriz != null)
                            _buildInfoRow(
                              Icons.home_work,
                              'Matriz',
                              direccion.direccionMatriz!,
                            ),
                          if (direccion.direccionMatriz != null)
                            const SizedBox(height: 8),
                          if (direccion.direccionSucursal != null)
                            _buildInfoRow(
                              Icons.store,
                              'Sucursal',
                              direccion.direccionSucursal!,
                            ),
                          if (direccion.direccionSucursal != null)
                            const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.phone,
                            'Teléfono',
                            direccion.telefono,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_city,
                            'Ciudad',
                            direccion.ciudad,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.map,
                            'Provincia',
                            direccion.provincia,
                          ),
                          if (direccion.codigoPostal != null)
                            const SizedBox(height: 8),
                          if (direccion.codigoPostal != null)
                            _buildInfoRow(
                              Icons.markunread_mailbox,
                              'Código Postal',
                              direccion.codigoPostal!,
                            ),
                          if (direccion.detallesAdicionales != null)
                            const SizedBox(height: 8),
                          if (direccion.detallesAdicionales != null)
                            _buildInfoRow(
                              Icons.info_outline,
                              'Detalles',
                              direccion.detallesAdicionales!,
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (!direccion.esPredeterminada)
                                TextButton.icon(
                                  onPressed: () =>
                                      _establecerPredeterminada(direccion.id),
                                  icon: const Icon(Icons.star_border, size: 18),
                                  label: const Text(
                                    'Default',
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
                                    _navegarAFormulario(direccion.id),
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
                                onPressed: () => _confirmarEliminar(
                                  direccion.id,
                                  direccion.alias,
                                ),
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
        Flexible(
          flex: 0,
          child: Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Future<void> _navegarAFormulario(int? id) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DireccionEnvioFormScreen(direccionId: id),
      ),
    );

    if (resultado == true) {
      _cargarDirecciones();
    }
  }

  Future<void> _establecerPredeterminada(int id) async {
    final service = Provider.of<DireccionesEnvioService>(
      context,
      listen: false,
    );
    final exito = await service.establecerPredeterminada(id);

    if (mounted) {
      if (exito) {
        CustomOverlayNotification.showSuccess(
          context,
          'Dirección establecida como predeterminada',
        );
      } else {
        CustomOverlayNotification.showError(
          context,
          'Error al establecer predeterminada',
        );
      }
    }
  }

  Future<void> _confirmarEliminar(int id, String alias) async {
    final confirmar = await CustomConfirmDialog.showDelete(
      context,
      itemName: alias,
      type: 'dirección',
    );

    if (confirmar && mounted) {
      final service = Provider.of<DireccionesEnvioService>(
        context,
        listen: false,
      );
      final exito = await service.eliminar(id);

      if (mounted) {
        if (exito) {
          CustomOverlayNotification.showSuccess(
            context,
            'Dirección eliminada exitosamente',
          );
        } else {
          CustomOverlayNotification.showError(
            context,
            'Error al eliminar dirección',
          );
        }
      }
    }
  }
}
