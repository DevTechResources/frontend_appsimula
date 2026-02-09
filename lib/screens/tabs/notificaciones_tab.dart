import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/firebase_messaging_service.dart';

class NotificacionesTab extends StatefulWidget {
  const NotificacionesTab({super.key});

  @override
  State<NotificacionesTab> createState() => _NotificacionesTabState();
}

class _NotificacionesTabState extends State<NotificacionesTab> {
  final _apiService = ApiService();
  final _fcmService = FirebaseMessagingService();

  String? _fcmToken;
  Map<String, dynamic>? _estadisticas;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _fcmService.getToken();
      final stats = await _apiService.getEstadisticasNotificaciones();

      setState(() {
        _fcmToken = token;
        _estadisticas = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _registerToken() async {
    if (_fcmToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay token FCM disponible')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.registrarTokenFCM(_fcmToken!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Token FCM registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token FCM
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Token FCM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_fcmToken != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _fcmToken!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    else
                      const Text('No hay token disponible'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _registerToken,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Registrar Token en Backend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estadísticas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Estadísticas de Notificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_estadisticas != null) ...[
                      _buildStatRow(
                        'Total de tokens:',
                        '${_estadisticas!['total']}',
                      ),
                      _buildStatRow(
                        'Tokens activos:',
                        '${_estadisticas!['activos']}',
                      ),
                      _buildStatRow(
                        'Tokens inactivos:',
                        '${_estadisticas!['inactivos']}',
                      ),
                    ] else
                      const Text('No hay estadísticas disponibles'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instrucciones
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '¿Cómo probar las notificaciones?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Asegúrate de que el token esté registrado\n'
                      '2. Ve a la pestaña "Facturas"\n'
                      '3. Selecciona una factura con saldo pendiente\n'
                      '4. Haz clic en "Pagar" y registra un pago\n'
                      '5. Verás un log en la consola del backend\n'
                      '6. La notificación se enviará automáticamente',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
