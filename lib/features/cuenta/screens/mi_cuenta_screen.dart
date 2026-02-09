import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/productos_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../models/cliente.dart';
import '../../auth/screens/login_tab.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final estaLogueado = authService.estaLogueado;
    final cliente = authService.clienteActual;

    if (!estaLogueado) {
      // Mostrar pantalla de login integrada
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Cuenta')),
        body: LoginTab(
          onLoginSuccess: (cliente) {
            // Después de login, navegar a Home
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del perfil
          _buildPerfilCard(context, cliente),
          const SizedBox(height: 24),

          // Preferencias
          _buildSeccionTitulo(context, 'Preferencias'),
          const SizedBox(height: 12),
          _buildPreferenciasCard(context),
          const SizedBox(height: 24),

          // Cuenta
          _buildSeccionTitulo(context, 'Cuenta'),
          const SizedBox(height: 12),
          _buildCuentaCard(context, authService),
        ],
      ),
    );
  }

  Widget _buildPerfilCard(BuildContext context, Cliente? cliente) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              child: Text(
                cliente?.nombre.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente?.nombre ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cliente?.email ?? 'email@ejemplo.com',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (cliente?.esInstalador == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(BuildContext context, String titulo) {
    return Text(
      titulo,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildPreferenciasCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildModoOscuroTile(context),
          const Divider(height: 1),
          const Divider(height: 1),
          _buildOpcionTile(context, Icons.language, 'Idioma', 'Español', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Función en desarrollo')),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModoOscuroTile(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDarkMode = themeService.isDarkMode;

    return ListTile(
      leading: Icon(
        isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Modo Oscuro'),
      subtitle: Text(isDarkMode ? 'Activado' : 'Desactivado'),
      trailing: Switch(
        value: isDarkMode,
        onChanged: (value) {
          themeService.toggleTheme();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? '🌙 Modo oscuro activado' : '☀️ Modo claro activado',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuentaCard(BuildContext context, AuthService authService) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildOpcionTile(
            context,
            Icons.receipt_long,
            'Datos de Facturación',
            'Gestionar datos fiscales',
            () {
              Navigator.pushNamed(context, '/datos-facturacion');
            },
          ),
          const Divider(height: 1),
          _buildOpcionTile(
            context,
            Icons.location_on,
            'Direcciones de Envío',
            'Gestionar direcciones de entrega',
            () {
              Navigator.pushNamed(context, '/direcciones-envio');
            },
          ),
          const Divider(height: 1),
          _buildOpcionTile(
            context,
            Icons.person_outline,
            'Editar Perfil',
            'Actualizar información personal',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función en desarrollo')),
              );
            },
          ),
          const Divider(height: 1),
          _buildOpcionTile(
            context,
            Icons.lock_outline,
            'Cambiar Contraseña',
            'Actualizar tu contraseña',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función en desarrollo')),
              );
            },
          ),
          const Divider(height: 1),
          _buildOpcionTile(
            context,
            Icons.logout,
            'Cerrar Sesión',
            'Salir de tu cuenta',
            () => _cerrarSesion(context, authService),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionTile(
    BuildContext context,
    IconData icon,
    String titulo,
    String subtitulo,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        titulo,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitulo),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _cerrarSesion(
    BuildContext context,
    AuthService authService,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Limpiar todos los servicios
      final productosService = Provider.of<ProductosService>(
        context,
        listen: false,
      );
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      final carritoService = Provider.of<CarritoService>(
        context,
        listen: false,
      );
      final favoritosService = Provider.of<FavoritosService>(
        context,
        listen: false,
      );
      final datosFacturacionService = Provider.of<DatosFacturacionService>(
        context,
        listen: false,
      );
      final direccionesEnvioService = Provider.of<DireccionesEnvioService>(
        context,
        listen: false,
      );

      productosService.clear();
      facturasService.clear();

      // 🛒 Limpiar solo el estado local (NO eliminar de BD)
      // El carrito persiste en la base de datos para futuras sesiones
      carritoService.limpiarCarritoLocal();
      favoritosService.limpiarFavoritosLocal();
      datosFacturacionService.limpiarDatos();
      direccionesEnvioService.limpiarDirecciones();

      // Cerrar sesión
      authService.cerrarSesion();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada. ¡Vuelve pronto!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
