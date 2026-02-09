import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../models/datos_facturacion.dart';

class DatosFacturacionFormScreen extends StatefulWidget {
  final int? datoId;

  const DatosFacturacionFormScreen({super.key, this.datoId});

  @override
  State<DatosFacturacionFormScreen> createState() =>
      _DatosFacturacionFormScreenState();
}

class _DatosFacturacionFormScreenState
    extends State<DatosFacturacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _empresaController = TextEditingController();
  final _rucCiController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();

  bool _esPredeterminado = false;
  bool _isLoading = false;
  DatosFacturacion? _datoActual;

  @override
  void initState() {
    super.initState();
    if (widget.datoId != null) {
      _cargarDato();
    }
  }

  Future<void> _cargarDato() async {
    final service = Provider.of<DatosFacturacionService>(
      context,
      listen: false,
    );
    _datoActual = service.datos.firstWhere((d) => d.id == widget.datoId);

    if (_datoActual != null) {
      setState(() {
        _aliasController.text = _datoActual!.alias;
        _razonSocialController.text = _datoActual!.razonSocial;
        _empresaController.text = _datoActual!.empresa ?? '';
        _rucCiController.text = _datoActual!.rucCi;
        _emailController.text = _datoActual!.email;
        _telefonoController.text = _datoActual!.telefono;
        _direccionController.text = _datoActual!.direccion;
        _ciudadController.text = _datoActual!.ciudad;
        _esPredeterminado = _datoActual!.esPredeterminado;
      });
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _razonSocialController.dispose();
    _empresaController.dispose();
    _rucCiController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.datoId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Datos' : 'Agregar Datos')),
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
                hintText: 'Ej: Mi empresa, Cliente ABC',
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

            // Razón Social
            TextFormField(
              controller: _razonSocialController,
              decoration: const InputDecoration(
                labelText: 'Razón Social / Nombres *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La razón social es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Empresa (opcional)
            TextFormField(
              controller: _empresaController,
              decoration: const InputDecoration(
                labelText: 'Empresa (Opcional)',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // RUC/CI
            TextFormField(
              controller: _rucCiController,
              decoration: const InputDecoration(
                labelText: 'RUC / Cédula *',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El RUC/CI es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El email es requerido';
                }
                if (!value.contains('@')) {
                  return 'Email inválido';
                }
                return null;
              },
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

            // Dirección
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: 'Dirección *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La dirección es requerida';
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

            // Predeterminado
            SwitchListTile(
              title: const Text('Establecer como predeterminado'),
              subtitle: const Text(
                'Usarás estos datos por defecto en tus compras',
              ),
              value: _esPredeterminado,
              onChanged: (value) {
                setState(() {
                  _esPredeterminado = value;
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

    setState(() {
      _isLoading = true;
    });

    final datos = {
      'alias': _aliasController.text.trim(),
      'razon_social': _razonSocialController.text.trim(),
      'empresa': _empresaController.text.trim().isEmpty
          ? null
          : _empresaController.text.trim(),
      'ruc_ci': _rucCiController.text.trim(),
      'email': _emailController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'direccion': _direccionController.text.trim(),
      'ciudad': _ciudadController.text.trim(),
      'es_predeterminado': _esPredeterminado,
    };

    final service = Provider.of<DatosFacturacionService>(
      context,
      listen: false,
    );
    bool exito;

    if (widget.datoId != null) {
      exito = await service.actualizar(widget.datoId!, datos);
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
          widget.datoId != null
              ? 'Datos actualizados exitosamente'
              : 'Datos creados exitosamente',
        );
        Navigator.pop(context, true);
      } else {
        CustomOverlayNotification.showError(
          context,
          'Error al guardar los datos',
        );
      }
    }
  }
}
