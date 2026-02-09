import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../models/datos_facturacion.dart';
import '../../../models/direccion_envio.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  DatosFacturacion? _datosSeleccionados;
  DireccionEnvio? _direccionSeleccionada;

  @override
  void initState() {
    super.initState();
    // Seleccionar automáticamente los predeterminados si existen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final datosFactService = context.read<DatosFacturacionService>();
      final direccionesService = context.read<DireccionesEnvioService>();

      setState(() {
        _datosSeleccionados =
            datosFactService.predeterminado ??
            (datosFactService.datos.isNotEmpty
                ? datosFactService.datos.first
                : null);
        _direccionSeleccionada =
            direccionesService.predeterminada ??
            (direccionesService.direcciones.isNotEmpty
                ? direccionesService.direcciones.first
                : null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final carritoService = context.watch<CarritoService>();
    final datosFactService = context.watch<DatosFacturacionService>();
    final direccionesService = context.watch<DireccionesEnvioService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Pedido'),
        backgroundColor: const Color(0xFF0B0F18),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 RESUMEN DEL PEDIDO
            _buildResumenCard(carritoService),
            const SizedBox(height: 24),

            // 📄 DATOS DE FACTURACIÓN
            _buildSeccionTitulo('Datos de Facturación', Icons.receipt),
            const SizedBox(height: 12),
            _buildDatosFacturacion(datosFactService),
            const SizedBox(height: 24),

            // 📍 DIRECCIÓN DE ENVÍO
            _buildSeccionTitulo('Dirección de Envío', Icons.local_shipping),
            const SizedBox(height: 12),
            _buildDireccionEnvio(direccionesService),
            const SizedBox(height: 32),

            // ✅ BOTÓN CONFIRMAR
            _buildBotonConfirmar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: const Color(0xFF0B0F18)),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildResumenCard(CarritoService carritoService) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Pedido',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${carritoService.cantidadTotal} producto(s)',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '\$${carritoService.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosFacturacion(DatosFacturacionService service) {
    if (service.datos.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'No tienes datos de facturación guardados',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega tus datos fiscales antes de continuar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/datos-facturacion');
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar Datos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0F18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: service.datos.map((dato) {
        final isSeleccionado = _datosSeleccionados?.id == dato.id;
        return Card(
          elevation: isSeleccionado ? 4 : 1,
          color: isSeleccionado ? Colors.blue[50] : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<DatosFacturacion>(
            value: dato,
            groupValue: _datosSeleccionados,
            onChanged: (value) {
              setState(() {
                _datosSeleccionados = value;
              });
            },
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    dato.alias,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dato.esPredeterminado) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  dato.razonSocial,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'RUC/CI: ${dato.rucCi}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            activeColor: const Color(0xFF0B0F18),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDireccionEnvio(DireccionesEnvioService service) {
    if (service.direcciones.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'No tienes direcciones de envío guardadas',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega una dirección de entrega antes de continuar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/direcciones-envio');
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar Dirección'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0F18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: service.direcciones.map((direccion) {
        final isSeleccionada = _direccionSeleccionada?.id == direccion.id;
        return Card(
          elevation: isSeleccionada ? 4 : 1,
          color: isSeleccionada ? Colors.green[50] : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<DireccionEnvio>(
            value: direccion,
            groupValue: _direccionSeleccionada,
            onChanged: (value) {
              setState(() {
                _direccionSeleccionada = value;
              });
            },
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    direccion.alias,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (direccion.esPredeterminada) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (direccion.direccionMatriz != null)
                  Text(
                    direccion.direccionMatriz!,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${direccion.ciudad}, ${direccion.provincia}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            activeColor: const Color(0xFF0B0F18),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBotonConfirmar() {
    final datosFactService = context.read<DatosFacturacionService>();
    final direccionesService = context.read<DireccionesEnvioService>();

    final bool puedeConfirmar =
        _datosSeleccionados != null &&
        _direccionSeleccionada != null &&
        datosFactService.datos.isNotEmpty &&
        direccionesService.direcciones.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: puedeConfirmar
            ? () {
                // Regresar con los datos seleccionados
                Navigator.pop(context, {
                  'datosFacturacion': _datosSeleccionados,
                  'direccionEnvio': _direccionSeleccionada,
                });
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0B0F18),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirmar Pedido',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
