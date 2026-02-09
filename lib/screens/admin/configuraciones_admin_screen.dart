import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_overlay_notification.dart';

/// Pantalla para configuraciones del administrador
/// Permite editar parámetros como IVA, correo de notificaciones, etc.
class ConfiguracionesAdminScreen extends StatefulWidget {
  const ConfiguracionesAdminScreen({super.key});

  @override
  State<ConfiguracionesAdminScreen> createState() =>
      _ConfiguracionesAdminScreenState();
}

class _ConfiguracionesAdminScreenState extends State<ConfiguracionesAdminScreen> {
  final ApiService _apiService = ApiService();
  
  // Controladores de formulario
  final _ivaController = TextEditingController();
  final _correoNotificacionesController = TextEditingController();
  
  // Estados
  bool _isLoadingIVA = false;
  bool _isLoadingCorreo = false;
  bool _isEditingIVA = false;
  bool _isEditingCorreo = false;
  
  @override
  void initState() {
    super.initState();
    _cargarConfiguraciones();
  }

  @override
  void dispose() {
    _ivaController.dispose();
    _correoNotificacionesController.dispose();
    super.dispose();
  }

  /// Cargar todas las configuraciones
  Future<void> _cargarConfiguraciones() async {
    await Future.wait([
      _cargarIVA(),
      _cargarCorreoNotificaciones(),
    ]);
  }

  /// Cargar IVA actual
  Future<void> _cargarIVA() async {
    setState(() => _isLoadingIVA = true);
    try {
      final response = await _apiService.get('/configuracion/iva');
      if (response != null && response['iva_porcentaje'] != null) {
        setState(() {
          _ivaController.text = response['iva_porcentaje'].toString();
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Error al cargar IVA: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingIVA = false);
    }
  }

  /// Cargar correo de notificaciones
  Future<void> _cargarCorreoNotificaciones() async {
    setState(() => _isLoadingCorreo = true);
    try {
      final response = await _apiService.get('/configuracion/correo-notificaciones');
      if (response != null && response['valor'] != null) {
        setState(() {
          _correoNotificacionesController.text = response['valor'];
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Error al cargar correo: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCorreo = false);
    }
  }

  /// Actualizar IVA
  Future<void> _actualizarIVA() async {
    final nuevoIVA = _ivaController.text.trim();
    
    if (nuevoIVA.isEmpty) {
      CustomSnackBar.showWarning(context, 'Ingresa un valor para el IVA');
      return;
    }

    final ivaNum = double.tryParse(nuevoIVA);
    if (ivaNum == null || ivaNum < 0 || ivaNum > 100) {
      CustomSnackBar.showError(
        context,
        'El IVA debe ser un número entre 0 y 100',
      );
      return;
    }

    setState(() => _isLoadingIVA = true);
    try {
      final response = await _apiService.put(
        '/configuracion/iva',
        {'iva_porcentaje': ivaNum},
      );

      if (response != null && response['message'] != null) {
        if (mounted) {
          CustomSnackBar.showSuccess(
            context,
            'IVA actualizado correctamente a ${nuevoIVA}%',
          );
          setState(() => _isEditingIVA = false);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Error al actualizar IVA: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingIVA = false);
    }
  }

  /// Actualizar correo de notificaciones
  Future<void> _actualizarCorreoNotificaciones() async {
    final nuevoCorreo = _correoNotificacionesController.text.trim();
    
    if (nuevoCorreo.isEmpty) {
      CustomSnackBar.showWarning(context, 'Ingresa un correo');
      return;
    }

    // Validar formato de correo
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(nuevoCorreo)) {
      CustomSnackBar.showError(context, 'Ingresa un correo válido');
      return;
    }

    setState(() => _isLoadingCorreo = true);
    try {
      final response = await _apiService.put(
        '/configuracion/correo-notificaciones',
        {'correo': nuevoCorreo},
      );

      if (response != null && response['message'] != null) {
        if (mounted) {
          CustomOverlayNotification.showSuccess(
            context,
            '✅ Correo actualizado correctamente',
          );
          setState(() => _isEditingCorreo = false);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Error al actualizar correo: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCorreo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones del Sistema'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📊 Sección IVA
            _buildConfiguracionCard(
              isDark: isDark,
              icon: Icons.percent,
              titulo: 'Impuesto IVA',
              descripcion: 'Porcentaje de IVA aplicado a facturas',
              isEditing: _isEditingIVA,
              isLoading: _isLoadingIVA,
              controller: _ivaController,
              onEdit: () => setState(() => _isEditingIVA = true),
              onCancel: () {
                _cargarIVA();
                setState(() => _isEditingIVA = false);
              },
              onSave: _actualizarIVA,
              suffix: '%',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 20),

            // 📧 Sección Correo de Notificaciones
            _buildConfiguracionCard(
              isDark: isDark,
              icon: Icons.email,
              titulo: 'Correo de Notificaciones',
              descripcion: 'Email para recibir notificaciones de pagos y abonos',
              isEditing: _isEditingCorreo,
              isLoading: _isLoadingCorreo,
              controller: _correoNotificacionesController,
              onEdit: () => setState(() => _isEditingCorreo = true),
              onCancel: () {
                _cargarCorreoNotificaciones();
                setState(() => _isEditingCorreo = false);
              },
              onSave: _actualizarCorreoNotificaciones,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 30),

            // ℹ️ Información
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 Información',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Los cambios se guardan inmediatamente en la base de datos\n'
                    '• No requiere reiniciar la aplicación\n'
                    '• El IVA se aplicará a futuras facturas\n'
                    '• Los correos de notificación se envían automáticamente cuando un cliente realiza un pago o abono',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget reutilizable para tarjetas de configuración
  Widget _buildConfiguracionCard({
    required bool isDark,
    required IconData icon,
    required String titulo,
    required String descripcion,
    required bool isEditing,
    required bool isLoading,
    required TextEditingController controller,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required VoidCallback onSave,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Icon(icon, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        descripcion,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Valor o Campo de edición
            if (!isEditing)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.text.isEmpty ? 'Sin configurar' : controller.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: controller.text.isEmpty
                              ? Colors.grey.shade500
                              : null,
                        ),
                      ),
                    ),
                    if (suffix != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        suffix,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: 'Ingresa el valor',
                  suffixText: suffix,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Botones
            if (!isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: isLoading ? null : onCancel,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onSave,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
