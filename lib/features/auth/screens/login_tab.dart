import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../core/services/firebase_messaging_service.dart';
import '../../../models/cliente.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../theme/app_theme.dart';
import '../../home/screens/home_screen.dart';

class LoginTab extends StatefulWidget {
  final Function(Cliente) onLoginSuccess;

  const LoginTab({super.key, required this.onLoginSuccess});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _loginResponse;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginResponse = null;
    });

    try {
      final response = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _loginResponse = response;
        _isLoading = false;
      });

      if (mounted) {
        // Crear objeto Cliente desde la respuesta
        final cliente = Cliente.fromJson(response['cliente']);

        // Actualizar AuthService
        Provider.of<AuthService>(context, listen: false).setCliente(cliente);

        // 🛒 CARGAR CARRITO, FAVORITOS, DATOS DE FACTURACIÓN Y DIRECCIONES
        final carritoService = Provider.of<CarritoService>(
          context,
          listen: false,
        );
        final favoritosService = Provider.of<FavoritosService>(
          context,
          listen: false,
        );
        final datosFactService = Provider.of<DatosFacturacionService>(
          context,
          listen: false,
        );
        final direccionesService = Provider.of<DireccionesEnvioService>(
          context,
          listen: false,
        );

        await Future.wait([
          carritoService.fetchCarrito(),
          favoritosService.fetchFavoritos(),
          datosFactService.fetchDatos(),
          direccionesService.fetchDirecciones(),
        ]).catchError((e) {
          print('⚠️ Error al cargar datos: $e');
          // Continuar sin bloquear
        });

        // �🔑 REGISTRAR TOKEN FCM SOLO AL HACER LOGIN
        // El token se guarda UNA SOLA VEZ por dispositivo en el backend
        try {
          await FirebaseMessagingService().registrarTokenEnBackend();
        } catch (e) {
          print('⚠️ Error al registrar token FCM: $e');
          // No bloqueamos el login si falla el registro del token
        }

        // ✅ MOSTRAR NOTIFICACIONES (mismo patrón que cerrar sesión)
        // 1️⃣ OVERLAY PEQUEÑO ARRIBA
        if (cliente.esInstalador) {
          CustomOverlayNotification.showWarning(
            context,
            'Acceso como Administrador',
          );
        } else {
          CustomOverlayNotification.showSuccess(
            context,
            '¡Bienvenido ${cliente.nombre}!',
          );
        }

        // 2️⃣ SNACKBAR GRANDE ABAJO (patrón directo como en cerrar sesión)
        if (mounted) {
          if (cliente.esInstalador) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bienvenido Admin - ${cliente.nombre}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sesión iniciada como ${cliente.nombre}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        // 3️⃣ Pequeño delay antes de navegar para ver las notificaciones
        await Future.delayed(const Duration(milliseconds: 800));

        // 4️⃣ NAVEGAR A HOME - GARANTIZADO
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _fillTestCredentials(String email) {
    _emailController.text = email;
    _passwordController.text = 'password123';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.account_circle, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),

            Text(
              'Iniciar Sesión',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un email';
                }
                if (!value.contains('@')) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa una contraseña';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Login Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B0F18),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),

            // Quick Test Buttons
            const Text(
              'Credenciales de Prueba:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _fillTestCredentials('admin@techsolutions.com'),
              icon: const Icon(Icons.business),
              label: const Text('TechSolutions (Mayorista)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B0F18),
                side: const BorderSide(color: Color(0xFF0B0F18)),
              ),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () => _fillTestCredentials('contacto@elecsur.com'),
              icon: const Icon(Icons.engineering),
              label: const Text('ElecSur (Instalador)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B0F18),
                side: const BorderSide(color: Color(0xFF0B0F18)),
              ),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () => _fillTestCredentials('juan.perez@gmail.com'),
              icon: const Icon(Icons.person),
              label: const Text('Juan Pérez (Público)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B0F18),
                side: const BorderSide(color: Color(0xFF0B0F18)),
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],

            // Login Response
            if (_loginResponse != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Login Exitoso',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliente: ${_loginResponse!['cliente']['razon_social'] ?? 'N/A'}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    Text(
                      'Email: ${_loginResponse!['cliente']['email'] ?? 'N/A'}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    Text(
                      'Rol: ${_loginResponse!['cliente']['categoria_cliente'] ?? 'cliente'}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Token guardado ✓',
                      style: TextStyle(
                        color: AppColors.success,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
