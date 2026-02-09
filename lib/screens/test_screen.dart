import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/firebase_messaging_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/theme_service.dart';
import '../models/cliente.dart';
import '../core/widgets/custom_overlay_notification.dart';
import '../core/widgets/custom_confirm_dialog.dart';
import '../theme/app_theme.dart';
import 'catalogo_screen.dart';
import '../features/auth/screens/login_tab.dart';
import '../features/productos/screens/productos_tab.dart';
import '../features/pedidos/screens/pedidos_tab.dart';
import '../features/facturas/screens/facturas_tab.dart';
import '../core/services/facturas_service.dart';
import '../features/notificaciones/screens/notificaciones_tab.dart';
import '../features/admin/screens/admin_home_screen.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoggedIn = false;
  Cliente? _currentUser;
  bool _esInstalador = false;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _initializeFirebaseMessaging();
    _checkLoginStatus();
  }

  void _initializeTabController() {
    final numTabs = _esInstalador ? 7 : 6;
    _createTabController(numTabs, initialIndex: 0);
  }

  void _createTabController(int length, {int initialIndex = 0}) {
    final oldController = _tabController;
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex,
    );

    // Calcular index de la pestaña "Facturas" según el número de tabs
    final facturasIndex = length == 7 ? 5 : 4;

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == facturasIndex) {
        try {
          final facturasService = Provider.of<FacturasService>(
            context,
            listen: false,
          );
          facturasService.notifyUpdated();
        } catch (_) {}
      }
    });

    // Dispose del controlador anterior si existe
    try {
      oldController.dispose();
    } catch (_) {}
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      await FirebaseMessagingService().initialize();
    } catch (e) {
      print('Error al inicializar Firebase Messaging: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  void _onLoginSuccess(Cliente usuario) {
    final bool cambiaRol = usuario.esInstalador != _esInstalador;

    if (cambiaRol) {
      // Si cambia el rol, necesitamos reconstruir todo
      // Recrear el TabController ANTES del setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createTabController(
          usuario.esInstalador ? 7 : 6,
          initialIndex: usuario.esInstalador ? 1 : 2,
        );
      });

      setState(() {
        _isLoggedIn = true;
        _currentUser = usuario;
        _esInstalador = usuario.esInstalador;
      });
    } else {
      // Mismo rol, solo actualizar estado y navegar
      setState(() {
        _isLoggedIn = true;
        _currentUser = usuario;
      });
      _tabController.animateTo(usuario.esInstalador ? 1 : 2);
    }
  }

  void _onLogout() async {
    final confirmar = await CustomConfirmDialog.show(
      context,
      title: '¿Cerrar sesión?',
      message: '¿Estás seguro de cerrar sesión?',
      confirmText: 'Cerrar Sesión',
      cancelText: 'Cancelar',
      icon: Icons.logout,
      confirmColor: Colors.red,
    );

    if (!confirmar) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Actualizar AuthService
    if (mounted) {
      Provider.of<AuthService>(context, listen: false).cerrarSesion();
      CustomOverlayNotification.showInfo(
        context,
        'Sesión cerrada. ¡Vuelve pronto!',
      );
    }

    final bool cambiaRol = _esInstalador;

    if (cambiaRol) {
      // Recrear TabController ANTES del setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createTabController(6, initialIndex: 1);
      });

      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
        _esInstalador = false;
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDarkMode = themeService.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // ✅ NO forzar backgroundColor - usa el tema automáticamente
        backgroundColor: _esInstalador
            ? const Color.fromARGB(
                255,
                65,
                58,
                48,
              ) // Color especial solo para admin
            : null, // null = usa el tema por defecto

        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo: Admin siempre usa logo_dark, usuarios normales cambian según tema
            Image.asset(
              _esInstalador
                  ? 'assets/images/logo_dark.png' // Admin: siempre logo_dark
                  : (isDarkMode
                        ? 'assets/images/logo_dark.png'
                        : 'assets/images/logo_live.png'),
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                // Fallback si no hay logo
                return Icon(
                  Icons.business,
                  size: 32,
                  color: _esInstalador
                      ? const Color.fromARGB(255, 255, 255, 255)
                      : colorScheme.onPrimary,
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              _esInstalador
                  ? 'Admin Panel - ${_currentUser?.nombre ?? "ElecSur"}'
                  : 'Tech Resources',
              style: TextStyle(
                // ✅ Color automático del tema
                color: _esInstalador
                    ? Colors.white
                    : null, // null = usa el tema
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),

        // ✅ Iconos usan color automático del tema
        iconTheme: _esInstalador
            ? const IconThemeData(color: Colors.white)
            : null, // null = usa el tema

        actions: [
          // Botón de toggle tema con icono que cambia
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeService.toggleTheme();
              CustomOverlayNotification.showInfo(
                context,
                isDarkMode ? 'Modo claro activado' : 'Modo oscuro activado',
              );
            },
            tooltip: isDarkMode ? 'Modo Claro' : 'Modo Oscuro',
          ),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _onLogout,
              tooltip: 'Cerrar sesión',
            ),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showInfo(context),
              tooltip: 'Información',
            ),
        ],

        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          // ✅ Los tabs también usan colores del tema automáticamente
          tabs: _esInstalador
              ? const [
                  Tab(icon: Icon(Icons.storefront), text: 'Catálogo'),
                  Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'),
                  Tab(icon: Icon(Icons.login), text: 'Login'),
                  Tab(icon: Icon(Icons.inventory), text: 'Productos'),
                  Tab(icon: Icon(Icons.shopping_cart), text: 'Pedidos'),
                  Tab(icon: Icon(Icons.receipt), text: 'Facturas'),
                  Tab(icon: Icon(Icons.notifications), text: 'Notificaciones'),
                ]
              : const [
                  Tab(icon: Icon(Icons.storefront), text: 'Catálogo'),
                  Tab(icon: Icon(Icons.login), text: 'Login'),
                  Tab(icon: Icon(Icons.inventory), text: 'Productos'),
                  Tab(icon: Icon(Icons.shopping_cart), text: 'Pedidos'),
                  Tab(icon: Icon(Icons.receipt), text: 'Facturas'),
                  Tab(icon: Icon(Icons.notifications), text: 'Notificaciones'),
                ],
        ),
      ),

      // Body - TabBarView
      body: TabBarView(
        controller: _tabController,
        children: _esInstalador
            ? [
                const CatalogoScreen(),
                const AdminHomeScreen(),
                LoginTab(onLoginSuccess: _onLoginSuccess),
                const ProductosTab(),
                const PedidosTab(),
                const FacturasTab(),
                const NotificacionesTab(),
              ]
            : [
                const CatalogoScreen(),
                LoginTab(onLoginSuccess: _onLoginSuccess),
                const ProductosTab(),
                const PedidosTab(),
                const FacturasTab(),
                const NotificacionesTab(),
              ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ℹ️ Información de Pruebas'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🔑 Credenciales de Prueba:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• admin@techsolutions.com'),
              Text('• contacto@elecsur.com'),
              Text('• juan.perez@gmail.com'),
              Text('Password: password123'),
              SizedBox(height: 16),
              Text(
                '📡 Backend:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• URL: http://localhost:3000'),
              Text('• Asegúrate de tener el servidor corriendo'),
              SizedBox(height: 16),
              Text(
                '🔔 Notificaciones:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Al crear un pago se enviará notificación'),
              Text('• Verás el log en la consola del backend'),
            ],
          ),
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
}
