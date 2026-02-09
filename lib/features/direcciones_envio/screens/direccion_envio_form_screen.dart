import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../models/direccion_envio.dart';

class DireccionEnvioFormScreen extends StatefulWidget {
  final int? direccionId;

  const DireccionEnvioFormScreen({super.key, this.direccionId});

  @override
  State<DireccionEnvioFormScreen> createState() =>
      _DireccionEnvioFormScreenState();
}

class _DireccionEnvioFormScreenState extends State<DireccionEnvioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _direccionMatrizController = TextEditingController();
  final _direccionSucursalController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _detallesAdicionalesController = TextEditingController();

  bool _esPredeterminada = false;
  bool _isLoading = false;
  DireccionEnvio? _direccionActual;

  @override
  void initState() {
    super.initState();
    if (widget.direccionId != null) {
      _cargarDireccion();
    }
  }

  Future<void> _cargarDireccion() async {
    final service = Provider.of<DireccionesEnvioService>(
      context,
      listen: false,
    );
    _direccionActual = service.direcciones.firstWhere(
      (d) => d.id == widget.direccionId,
    );

    if (_direccionActual != null) {
      setState(() {
        _aliasController.text = _direccionActual!.alias;
        _direccionMatrizController.text =
            _direccionActual!.direccionMatriz ?? '';
        _direccionSucursalController.text =
            _direccionActual!.direccionSucursal ?? '';
        _telefonoController.text = _direccionActual!.telefono;
        _ciudadController.text = _direccionActual!.ciudad;
        _provinciaController.text = _direccionActual!.provincia;
        _codigoPostalController.text = _direccionActual!.codigoPostal ?? '';
        _detallesAdicionalesController.text =
            _direccionActual!.detallesAdicionales ?? '';
        _esPredeterminada = _direccionActual!.esPredeterminada;
      });
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _direccionMatrizController.dispose();
    _direccionSucursalController.dispose();
    _telefonoController.dispose();
    _ciudadController.dispose();
    _provinciaController.dispose();
    _codigoPostalController.dispose();
    _detallesAdicionalesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.direccionId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Dirección' : 'Agregar Dirección'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Alias
            TextFormField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Nombre Identificador *',
                hintText: 'Ej: Mi Casa, Oficina, Obra Guayaquil',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Dirección Matriz
            TextFormField(
              controller: _direccionMatrizController,
              decoration: const InputDecoration(
                labelText: 'Dirección / Matriz',
                hintText: 'Calle principal, número, edificio',
                prefixIcon: Icon(Icons.home_work),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Dirección Sucursal
            TextFormField(
              controller: _direccionSucursalController,
              decoration: const InputDecoration(
                labelText: 'Dirección / Sucursal',
                hintText: 'Dirección alternativa o de sucursal',
                prefixIcon: Icon(Icons.store),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Teléfono
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El teléfono es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ciudad
            TextFormField(
              controller: _ciudadController,
              decoration: const InputDecoration(
                labelText: 'Ciudad *',
                prefixIcon: Icon(Icons.location_city),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La ciudad es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Provincia
            TextFormField(
              controller: _provinciaController,
              decoration: const InputDecoration(
                labelText: 'Provincia *',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La provincia es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Código Postal
            TextFormField(
              controller: _codigoPostalController,
              decoration: const InputDecoration(
                labelText: 'Código Postal (Opcional)',
                prefixIcon: Icon(Icons.markunread_mailbox),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Detalles Adicionales
            TextFormField(
              controller: _detallesAdicionalesController,
              decoration: const InputDecoration(
                labelText: 'Detalles Adicionales (Opcional)',
                hintText: 'Ej: Apartamento 3B, Casa azul, Referencia',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Nota de ayuda
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Debe proporcionar al menos una dirección (Matriz o Sucursal)',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Predeterminada
            SwitchListTile(
              title: const Text('Establecer como predeterminada'),
              subtitle: const Text(
                'Usarás esta dirección por defecto en tus envíos',
              ),
              value: _esPredeterminada,
              onChanged: (value) {
                setState(() {
                  _esPredeterminada = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Botón Guardar
            ElevatedButton(
              onPressed: _isLoading ? null : _guardar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar que al menos una dirección esté presente
    if (_direccionMatrizController.text.trim().isEmpty &&
        _direccionSucursalController.text.trim().isEmpty) {
      CustomOverlayNotification.showWarning(
        context,
        'Debe proporcionar al menos una dirección',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final datos = {
      'alias': _aliasController.text.trim(),
      'direccion_matriz': _direccionMatrizController.text.trim().isEmpty
          ? null
          : _direccionMatrizController.text.trim(),
      'direccion_sucursal': _direccionSucursalController.text.trim().isEmpty
          ? null
          : _direccionSucursalController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'ciudad': _ciudadController.text.trim(),
      'provincia': _provinciaController.text.trim(),
      'codigo_postal': _codigoPostalController.text.trim().isEmpty
          ? null
          : _codigoPostalController.text.trim(),
      'detalles_adicionales': _detallesAdicionalesController.text.trim().isEmpty
          ? null
          : _detallesAdicionalesController.text.trim(),
      'es_predeterminada': _esPredeterminada,
    };

    final service = Provider.of<DireccionesEnvioService>(
      context,
      listen: false,
    );
    bool exito;

    if (widget.direccionId != null) {
      exito = await service.actualizar(widget.direccionId!, datos);
    } else {
      exito = await service.crear(datos);
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (exito) {
        CustomOverlayNotification.showSuccess(
          context,
          widget.direccionId != null
              ? 'Dirección actualizada exitosamente'
              : 'Dirección creada exitosamente',
        );
        Navigator.pop(context, true);
      } else {
        CustomOverlayNotification.showError(
          context,
          'Error al guardar la dirección',
        );
      }
    }
  }
}
