import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import '../core/services/carrito_service.dart';
import '../core/services/favoritos_service.dart';
import '../features/home/screens/home_screen.dart';
import '../features/productos/screens/productos_tab.dart';
import '../features/facturas/screens/facturas_tab.dart';
import '../features/credito/screens/credito_tab.dart';
import '../features/cuenta/screens/mi_cuenta_screen.dart';
import '../features/carrito/screens/carrito_screen.dart';
import '../features/favoritos/screens/favoritos_screen.dart';
import '../features/auth/screens/login_tab.dart';
import '../features/admin/screens/admin_home_screen.dart';
import '../models/cliente.dart';

// Clase personalizada para posicionar el botón Admin encima del área de Total en el carrito
class _AdminButtonLocationAboveTotal extends FloatingActionButtonLocation {
  const _AdminButtonLocationAboveTotal();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Posición X: alineado a la derecha con un margen
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;

    // Posición Y: encima del bottomNavigationBar y el área de Total
    // El bottomNavigationBar tiene altura ~56, el área de Total ~150
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        scaffoldGeometry.minInsets.bottom -
        (scaffoldGeometry.bottomSheetSize.height > 0
            ? scaffoldGeometry.bottomSheetSize.height
            : 206.0); // 56 (navbar) + 150 (total area aproximadamente)

    return Offset(fabX, fabY);
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  // Instancia global para acceso desde otras pantallas
  static MainScreenState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    _instance = null;
    _searchController.dispose();
    super.dispose();
  }

  // Método estático para obtener la instancia
  static MainScreenState? get instance => _instance;

  // Método público para cambiar de pestaña (usado por home_screen y otros)
  void cambiarPestana(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Método estático para cambiar de pestaña desde cualquier lugar
  static void cambiarPestanaGlobal(int index) {
    _instance?.cambiarPestana(index);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onLoginSuccess(Cliente cliente) async {
    if (mounted) {
      Provider.of<AuthService>(context, listen: false).iniciarSesion(cliente);

      // 🛒 CARGAR CARRITO Y FAVORITOS DEL USUARIO
      final carritoService = Provider.of<CarritoService>(
        context,
        listen: false,
      );
      final favoritosService = Provider.of<FavoritosService>(
        context,
        listen: false,
      );

      await Future.wait([
        carritoService.fetchCarrito(),
        favoritosService.fetchFavoritos(),
      ]);

      // Cambiar a la pestaña de Inicio (Home) después del login
      setState(() {
        _selectedIndex = 0; // Índice de Home
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido, ${cliente.nombre}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  List<Widget> _getScreens() {
    return [
      HomeScreen(onNavigate: cambiarPestana), // 0 - Inicio con callback
      const ProductosTab(), // 1 - Productos
      const CarritoScreen(), // 2 - Carrito
      const CreditoTab(), // 3 - Crédito (reemplaza Facturas)
      const MiCuentaScreen(), // 4 - Mi Cuenta
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final carritoService = Provider.of<CarritoService>(context);
    final estaLogueado = authService.estaLogueado;

    // Determinar si estamos en el carrito y si tiene items
    final estoyEnCarrito = _selectedIndex == 2;
    final carritoTieneItems = carritoService.items.isNotEmpty;

    // Si no está logueado y está en una pantalla que requiere login (excepto Inicio y Productos)
    // REMOVIDO: Ya no mostrar LoginTab aquí, las pantallas individuales manejan el no login

    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(index: _selectedIndex, children: _getScreens()),
      bottomNavigationBar: _buildBottomNavigationBar(context),
      // Botón Admin con posición dinámica
      //BOTON ADMIN DESACTIVADO POR AHORA
/*       floatingActionButton: authService.esInstalador
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminHomeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin'),
              backgroundColor: Colors.purple,
            )
          : null, */
      // Posición dinámica:
      // - En carrito con items: Encima del área de "Total"
      // - En otras situaciones: Abajo a la derecha (posición normal)
      floatingActionButtonLocation: estoyEnCarrito && carritoTieneItems
          ? const _AdminButtonLocationAboveTotal()
          : FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final favoritosService = Provider.of<FavoritosService>(context);
    final theme = Theme.of(context);

    return AppBar(
      title: Row(
        children: [
          // Logo - Siempre usa el logo blanco (modo oscuro)
          Image.asset(
            'assets/images/logo_dark.png', // Siempre logo blanco
            height: 32,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.business,
                size: 32,
                color: theme.colorScheme.onPrimary,
              );
            },
          ),
          const SizedBox(width: 12),
          const Text(
            'Tech Resources',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      actions: [
        // Buscador
        if (_selectedIndex == 1) // Solo mostrar en Productos
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
            tooltip: 'Buscar',
          ),
        // Favoritos con badge
        if (authService.estaLogueado)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritosScreen(),
                    ),
                  );
                },
                tooltip: 'Favoritos',
              ),
              if (favoritosService.cantidadFavoritos > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.pinkAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      favoritosService.cantidadFavoritos > 99
                          ? '99+'
                          : '${favoritosService.cantidadFavoritos}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        // Info de pruebas
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showInfo(context),
          tooltip: 'Información',
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final carritoService = Provider.of<CarritoService>(context);
    final cantidadCarrito = carritoService.cantidadTotal;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Productos',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (cantidadCarrito > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cantidadCarrito > 99 ? '99+' : '$cantidadCarrito',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          activeIcon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart),
              if (cantidadCarrito > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cantidadCarrito > 99 ? '99+' : '$cantidadCarrito',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Carrito',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.credit_card_outlined),
          activeIcon: Icon(Icons.credit_card),
          label: 'Crédito',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Mi Cuenta',
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar Producto'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Nombre del producto...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            // Aquí puedes implementar la lógica de búsqueda
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Buscando: $value')));
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implementar búsqueda
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Buscando: ${_searchController.text}')),
              );
            },
            child: const Text('Buscar'),
          ),
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
