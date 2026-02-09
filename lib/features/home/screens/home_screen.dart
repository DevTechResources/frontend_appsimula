import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/productos_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../models/cliente.dart';
import '../../../models/producto.dart';
import '../../productos/screens/producto_detalle_screen.dart';
import '../../../screens/main_screen.dart';
import 'package:flutter/rendering.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, WidgetsBindingObserver {
  bool _usuarioInteractuandoBanner = false;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  // Banners de promociones
  final List<String> _banners = [
    'assets/images/teclam_movil.png',
    'assets/images/witek_movil.png',
  ];

  // 🏷️ MARCAS - 11 logos para auto-scroll
  final List<String> _marcas = [
    'assets/images/marcas/marca1.png',
    'assets/images/marcas/marca2.png',
    'assets/images/marcas/marca3.png',
    'assets/images/marcas/marca4.png',
    'assets/images/marcas/marca5.png',
    'assets/images/marcas/marca6.png',
  ];

  // 🔄 CONTROLADORES PARA MÁS COMPRADOS Y NOVEDADES
  late PageController _masCompradosController;
  late PageController _novedadesController;
  late PageController _marcasController;
  Timer? _masCompradosTimer;
  Timer? _novedadesTimer;
  Timer? _marcasTimer;
  bool _usuarioInteractuandoMasComprados = false;
  bool _usuarioInteractuandoNovedades = false;
  bool _usuarioInteractuandoMarcas = false;
  int _currentMasCompradosIndex = 0;
  int _currentNovedadesIndex = 0;
  int _currentMarcasIndex = 0;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores de productos
    _masCompradosController = PageController(viewportFraction: 0.85);
    _novedadesController = PageController(viewportFraction: 0.85);
    _marcasController = PageController(viewportFraction: 0.7);

    _startBannerAutoScroll();
    // Cargar productos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final productosService = Provider.of<ProductosService>(
        context,
        listen: false,
      );
      if (productosService.productos.isEmpty) {
        productosService.fetchProductos();
      }
    });
    // Escuchar ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();

    // Limpiar timers y controladores de productos
    _masCompradosTimer?.cancel();
    _novedadesTimer?.cancel();
    _marcasTimer?.cancel();
    _masCompradosController.dispose();
    _novedadesController.dispose();
    _marcasController.dispose();

    WidgetsBinding.instance.removeObserver(this);
    // Unsubscribe RouteObserver
    try {
      final route = ModalRoute.of(context);
      if (route != null) routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suscribir al RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  // RouteAware callbacks
  @override
  void didPush() {
    if (mounted) _refreshProductos();
  }

  @override
  void didPopNext() {
    if (mounted) _refreshProductos();
  }

  // App lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshProductos();
    }
  }

  void _refreshProductos() {
    if (!mounted) return;
    final productosService = Provider.of<ProductosService>(
      context,
      listen: false,
    );
    productosService.fetchProductos();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();

    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_bannerController.hasClients) return;
      if (_usuarioInteractuandoBanner) return; // ⛔ NO MOVER SI USUARIO TOCA

      final nextPage = (_currentBannerIndex + 1) % _banners.length;

      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final productosService = Provider.of<ProductosService>(context);
    final cliente = authService.clienteActual;
    final estaLogueado = authService.estaLogueado;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Obtener TODOS los productos activos (incluye sin stock)
    final productosActivos = productosService.productosActivos;
    final productosDestacados = productosActivos.take(6).toList();
    final novedades = productosActivos.reversed.take(6).toList();

    return RefreshIndicator(
      onRefresh: () => productosService.fetchProductos(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carrusel de Banners con gradiente mejorado
            _buildBannerCarousel(context),
            const SizedBox(height: 8),

            // Contenido principal con padding
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1A1C1E), const Color(0xFF252A35)]
                      : [Colors.grey.shade50, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Saludo personalizado mejorado
                    _buildSaludoCompacto(
                      context,
                      estaLogueado,
                      cliente,
                      isDark,
                    ),
                    const SizedBox(height: 24),

                    // Mostrar loading si está cargando
                    if (productosService.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      // Productos Más Comprados
                      _buildSeccionProductos(
                        context,
                        titulo: 'Más Comprados',
                        productos: productosDestacados,
                        color: isDark
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color(0xFF0B0F18),
                        isDark: isDark,
                        seccionId: 'masComprados',
                      ),
                      const SizedBox(height: 24),

                      // 🏷️ MARCAS - Auto-scroll
                      _buildSeccionMarcas(context, isDark),
                      const SizedBox(height: 24),

                      // Novedades del Mes
                      _buildSeccionProductos(
                        context,
                        titulo: 'Novedades del Mes',
                        productos: novedades,
                        color: isDark
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color(0xFF0B0F18),
                        isDark: isDark,
                        seccionId: 'novedades',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carrusel de Banners
  Widget _buildBannerCarousel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              _usuarioInteractuandoBanner =
                  notification.direction != ScrollDirection.idle;
              return false;
            },
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.asset(
                  _banners[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),

          // 🔘 INDICADORES
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentBannerIndex == index ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentBannerIndex == index
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBannerColor(int index) {
    switch (index) {
      case 0:
        return Colors.red.shade700; // Navidad
      case 1:
        return Colors.orange.shade700; // Ofertas
      case 2:
        return Colors.blue.shade700; // Nuevos
      default:
        return Colors.purple.shade700;
    }
  }

  IconData _getBannerIcon(int index) {
    switch (index) {
      case 0:
        return Icons.card_giftcard;
      case 1:
        return Icons.local_offer;
      case 2:
        return Icons.new_releases;
      default:
        return Icons.shopping_bag;
    }
  }

  String _getBannerText(int index) {
    switch (index) {
      case 0:
        return '🎄 Navidad 2025';
      case 1:
        return '🔥 Ofertas Especiales';
      case 2:
        return '✨ Nuevos Productos';
      default:
        return 'Tech Resources';
    }
  }

  String _getBannerSubtext(int index) {
    switch (index) {
      case 0:
        return 'Hasta 30% de descuento';
      case 1:
        return 'Precios increíbles';
      case 2:
        return 'Lo último en tecnología';
      default:
        return 'Tu tienda de confianza';
    }
  }

  // Saludo compacto
  Widget _buildSaludoCompacto(
    BuildContext context,
    bool estaLogueado,
    Cliente? cliente,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2E3440), const Color(0xFF1E2530)]
              : [Colors.white, Colors.grey.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [Colors.white, Colors.white70]
                        : [Colors.black87, Colors.black54],
                  ).createShader(bounds),
                  child: Text(
                    estaLogueado
                        ? '¡Hola, ${cliente?.nombre?.split(' ').first ?? "Usuario"}! 👋'
                        : '¡Bienvenido! 👋',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  estaLogueado
                      ? 'Descubre nuestros productos exclusivos'
                      : 'Inicia sesión para comenzar tu experiencia',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!estaLogueado)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF1E88E5) // fondo en modo oscuro
                    : const Color(0xFF0B0F18), // fondo en modo claro
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    MainScreenState.cambiarPestanaGlobal(4);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      'Iniciar',
                      style: TextStyle(
                        color: isDark
                            ? const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ) // texto dark
                            : const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ), // texto light
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Sección de productos con scroll horizontal
  Widget _buildSeccionProductos(
    BuildContext context, {
    required String titulo,
    required List<Producto>? productos,
    required Color color,
    required bool isDark,
    required String seccionId,
  }) {
    if (productos == null || productos.isEmpty) {
      return const SizedBox.shrink();
    }

    // Obtener el controlador y las variables según la sección
    late PageController controller;
    late bool usuarioInteractuando;
    late int currentIndex;
    late Timer? timer;
    late Function(bool) setUserInteracting;
    late Function(int) setCurrentIndex;
    late Function(Timer?) setTimer;

    if (seccionId == 'masComprados') {
      controller = _masCompradosController;
      usuarioInteractuando = _usuarioInteractuandoMasComprados;
      currentIndex = _currentMasCompradosIndex;
      timer = _masCompradosTimer;
      setUserInteracting = (value) {
        setState(() => _usuarioInteractuandoMasComprados = value);
      };
      setCurrentIndex = (value) {
        setState(() => _currentMasCompradosIndex = value);
      };
      setTimer = (value) {
        _masCompradosTimer = value;
      };
    } else {
      controller = _novedadesController;
      usuarioInteractuando = _usuarioInteractuandoNovedades;
      currentIndex = _currentNovedadesIndex;
      timer = _novedadesTimer;
      setUserInteracting = (value) {
        setState(() => _usuarioInteractuandoNovedades = value);
      };
      setCurrentIndex = (value) {
        setState(() => _currentNovedadesIndex = value);
      };
      setTimer = (value) {
        _novedadesTimer = value;
      };
    }

    // Iniciar auto-scroll si no está activo
    if (timer == null && !usuarioInteractuando) {
      _startProductoAutoScroll(
        controller,
        setUserInteracting,
        setTimer,
        seccionId,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ).createShader(bounds),
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.white10, Colors.white.withOpacity(0.05)]
                      : [Colors.black12, Colors.black.withOpacity(0.05)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    DefaultTabController.of(context).animateTo(1);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Ver todos',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.forward ||
                  notification.direction == ScrollDirection.reverse) {
                setUserInteracting(true);
                timer?.cancel();
                setTimer(null);
              }
              return false;
            },
            child: PageView.builder(
              controller: controller,
              onPageChanged: (index) {
                setCurrentIndex(index);
              },
              itemCount: productos.length,
              itemBuilder: (context, index) {
                return _buildProductoCard(
                  context,
                  productos[index],
                  color,
                  isDark,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Método para iniciar auto-scroll de productos
  void _startProductoAutoScroll(
    PageController controller,
    Function(bool) setUserInteracting,
    Function(Timer?) setTimer,
    String seccionId,
  ) {
    if (!mounted) return;

    final timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_usuarioInteractuandoBanner ||
          (seccionId == 'masComprados' && _usuarioInteractuandoMasComprados) ||
          (seccionId == 'novedades' && _usuarioInteractuandoNovedades)) {
        // Usuario está interactuando, no hacer nada
        return;
      }

      if (controller.hasClients) {
        final nextPage =
            (controller.page!.toInt() + 1) %
            (seccionId == 'masComprados' ? 5 : 6); // Ajusta según tus datos

        controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });

    setTimer(timer);
  }

  Widget _buildProductoCard(
    BuildContext context,
    Producto producto,
    Color accentColor,
    bool isDark,
  ) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final estaLogueado = authService.estaLogueado;
    final sinStock = producto.stock <= 0;

    return AnimatedOpacity(
      opacity: sinStock ? 0.85 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductoDetalleScreen(producto: producto),
            ),
          );
        },
        child: Container(
          width:
              MediaQuery.of(context).size.width *
              0.5, // Aumentado de 0.45 a 0.5 para más espacio
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF2E3440), const Color(0xFF1E2530)]
                  : [Colors.white, Colors.grey.shade50],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.white.withOpacity(0.8),
                blurRadius: 10,
                offset: const Offset(-5, -5),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen del producto con Hero
                  Hero(
                    tag: 'producto_home_${producto.id}',
                    child: Container(
                      height: 150, // Aumentado de 140 a 150 para más espacio
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withOpacity(0.15),
                            accentColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child:
                          producto.imagen != null && producto.imagen!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                producto.imagen!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accentColor.withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_rounded,
                                        size: 48,
                                        color: accentColor,
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          color: accentColor,
                                          strokeWidth: 3,
                                        ),
                                      );
                                    },
                              ),
                            )
                          : Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withOpacity(0.2),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  size: 48,
                                  color: accentColor,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // Información del producto
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🏷️ Nombre del producto
                          Text(
                            producto.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // 💰 Precio y stock SOLO si está logueado
                          if (estaLogueado) ...[
                            Text(
                              '\$${producto.precio.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),

                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Stock: ${producto.stock}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color:
                                        (producto.activo && producto.stock > 0)
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    (producto.activo && producto.stock > 0)
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color:
                                        (producto.activo && producto.stock > 0)
                                        ? Colors.green
                                        : Colors.red,
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // 🔒 Mensaje solo cuando NO está logueado
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          Colors.white10,
                                          Colors.white.withOpacity(0.05),
                                        ]
                                      : [
                                          Colors.black12,
                                          Colors.black.withOpacity(0.05),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Inicia sesión para ver precio',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 6),

                          // 🏷️ CATEGORÍA → SIEMPRE VISIBLE
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              producto.categoriaNombre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Badge de NO DISPONIBLE si no hay stock
              if (sinStock)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AGOTADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBienvenida(
    BuildContext context,
    bool estaLogueado,
    Cliente? cliente,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            estaLogueado
                ? '¡Hola, ${cliente?.nombre ?? "Usuario"}!'
                : '¡Bienvenido!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            estaLogueado
                ? 'Tech Resources a tu servicio'
                : 'Inicia sesión para comenzar',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (!estaLogueado) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navegar a la pestaña de login (índice 4 - Mi Cuenta)
                DefaultTabController.of(context).animateTo(4);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Iniciar Sesión'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInformacion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acerca de Tech Resources',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          Icons.info_outline,
          'Empresa',
          'Soluciones tecnológicas de calidad para tu negocio',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          context,
          Icons.phone,
          'Contacto',
          'Atención al cliente disponible',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          context,
          Icons.local_shipping,
          'Envíos',
          'Entrega rápida y segura',
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🏷️ SECCIÓN DE MARCAS CON AUTO-SCROLL
  Widget _buildSeccionMarcas(BuildContext context, bool isDark) {
    if (_marcasTimer == null && !_usuarioInteractuandoMarcas) {
      _startMarcasAutoScroll();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marcas Destacadas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0B0F18),
          ),
        ),

        const SizedBox(height: 4), // 🔥 aún más pegado

        SizedBox(
          height: 64,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              setState(() => _usuarioInteractuandoMarcas = true);
              _marcasTimer?.cancel();
              _marcasTimer = null;
              return false;
            },
            child: ListView.builder(
              controller: _marcasController,
              scrollDirection: Axis.horizontal,
              itemCount: _marcas.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return _buildMarcaItem(_marcas[index], isDark);
              },
            ),
          ),
        ),
      ],
    );
  }

  // Card individual de marca
  Widget _buildMarcaItem(String marcaPath, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 12,
      ), // 🔥 separación real entre logos
      child: Image.asset(
        marcaPath,
        fit: BoxFit.contain,
        height: 52, // 🔥 MÁS GRANDE y visible
        errorBuilder: (_, __, ___) {
          return Icon(
            Icons.image_not_supported_outlined,
            size: 28,
            color: isDark ? Colors.white30 : Colors.grey,
          );
        },
      ),
    );
  }

  // Auto-scroll de marcas
  void _startMarcasAutoScroll() {
    if (!mounted) return;

    _marcasTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_usuarioInteractuandoBanner || _usuarioInteractuandoMarcas) {
        return;
      }

      if (_marcasController.hasClients) {
        final nextPage = (_currentMarcasIndex + 1) % _marcas.length;

        _marcasController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }
}
