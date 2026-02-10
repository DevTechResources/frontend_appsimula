import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/producto.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../theme/app_theme.dart';
import '../widgets/productos_similares_widget.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen>
    with SingleTickerProviderStateMixin {
  int _cantidad = 1;
  bool _invertido = false; // 🔄 controla el intercambio
  bool _descripcionExpandida = false;
  bool _mostrarScrollToTop = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    // Inicializar ScrollController
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    // Mostrar botón cuando se haya desplazado más de 200 pixels
    if (_scrollController.offset > 200 && !_mostrarScrollToTop) {
      setState(() {
        _mostrarScrollToTop = true;
      });
    } else if (_scrollController.offset <= 200 && _mostrarScrollToTop) {
      setState(() {
        _mostrarScrollToTop = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producto.nombre),
        actions: [
          // Botón de favoritos
          Consumer<FavoritosService>(
            builder: (context, favoritosService, child) {
              final esFavorito = favoritosService.esFavorito(
                widget.producto.id,
              );
              return IconButton(
                icon: Icon(
                  esFavorito ? Icons.favorite : Icons.favorite_border,
                  color: esFavorito ? Colors.pinkAccent : null,
                ),
                onPressed: () async {
                  final authService = context.read<AuthService>();
                  if (!authService.estaLogueado) {
                    CustomSnackBar.showWarning(
                      context,
                      'Debes iniciar sesión para usar favoritos',
                    );
                    return;
                  }

                  if (esFavorito) {
                    // Confirmar eliminación
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Quitar de favoritos?'),
                        content: Text(
                          'Este producto ya está en tu lista de favoritos.\n\n¿Deseas quitarlo?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Quitar'),
                          ),
                        ],
                      ),
                    );

                    if (confirmar == true) {
                      final success = await favoritosService.eliminarFavorito(
                        widget.producto.id,
                      );
                      if (success && mounted) {
                        CustomOverlayNotification.showInfo(
                          context,
                          'Eliminado de favoritos',
                        );
                      }
                    }
                  } else {
                    // Agregar a favoritos
                    final success = await favoritosService.agregarFavorito(
                      widget.producto,
                    );
                    if (success && mounted) {
                      CustomOverlayNotification.showSuccess(
                        context,
                        '${widget.producto.nombre} agregado a favoritos ❤️',
                      );
                    }
                  }
                },
                tooltip: esFavorito
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
              );
            },
          ),
          // Botón del carrito con badge
          Consumer<CarritoService>(
            builder: (context, carrito, child) {
              final cantidadItems = carrito.cantidadTotal;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () => Navigator.pushNamed(context, '/carrito'),
                  ),
                  if (cantidadItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          cantidadItems > 99 ? '99+' : '$cantidadItems',
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
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagenProducto(isDark),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNombreYPrecio(theme, isDark),
                  const SizedBox(height: 12),
                  _buildStockInfo(theme, isDark),
                  const SizedBox(height: 10),
                  Divider(color: theme.dividerColor),
                  const SizedBox(height: 10),
                  _buildDescripcion(theme, isDark),
                  const SizedBox(height: 12),
                  _buildPrecioTotal(theme, isDark),
                ],
              ),
            ),
            // Widget de productos similares
            ProductosSimilaresWidget(
              productoId: widget.producto.id,
              categoriaId: widget.producto.categoriaId,
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
      bottomNavigationBar: _buildSelectorCantidad(theme, isDark),
      // Botón flotante de scroll to top
      floatingActionButton: _mostrarScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildImagenProducto(bool isDark) {
    return Hero(
      tag: 'producto_${widget.producto.id}',
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1C1E),
                        const Color(0xFF2D3748),
                        const Color(0xFF1E2530),
                      ]
                    : [
                        Colors.grey.shade50,
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                      ],
              ),
            ),
            child:
                widget.producto.imagen != null &&
                    widget.producto.imagen!.isNotEmpty
                ? Stack(
                    children: [
                      Image.network(
                        widget.producto.imagen!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagenPlaceholder(isDark),
                      ),
                      // Overlay decorativo con gradiente radial
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.5,
                            colors: [
                              Colors.transparent,
                              (isDark ? Colors.black : Colors.white)
                                  .withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildImagenPlaceholder(isDark),
          ),
          // 💰 Precio del producto (lado izquierdo)
          Positioned(
            top: 20,
            left: 20,
            child: _buildPrecioOverlay(
              precio: widget.producto.precio,
              isDark: isDark,
              scale: 0.85, // 🔥 más pequeño (prueba 0.7 – 0.85)
            ),
          ),

          // 💰 Precio del producto (lado izquierdo)
          Positioned(
            top: 20,
            left: 20,
            child: _buildPrecioOverlay(
              precio: widget.producto.precio,
              isDark: isDark,
              scale: 0.85,
            ),
          ),

          // Gradiente overlay superior
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 120)),

          // Gradiente overlay inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 150),
          ),

          // 👁️ Vista previa
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                _mostrarVistaPreviaImagen(
                  context: context,
                  imagenUrl: widget.producto.imagen,
                  isDark: isDark,
                  widthFactor: 0.85,
                  heightFactor: 0.6,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Vista previa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecioOverlay({
    required double precio,
    required bool isDark,
    double scale = 0.85, // 🔥 controla TODO el tamaño aquí
  }) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final estaLogueado = authService.estaLogueado;

    if (!estaLogueado) {
      return Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Iniciar Sesión para ver el precio',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.attach_money_rounded,
                color: Colors.white,
                size: 18, // 🔽 reducido
              ),
            ),
            const SizedBox(width: 8),
            Text(
              precio.toStringAsFixed(2),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18, // 🔽 reducido
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'USD',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12, // 🔽 reducido
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Para visualizar la imagen en vista previa:
  void _mostrarVistaPreviaImagen({
    required BuildContext context,
    required String? imagenUrl,
    required bool isDark,
    double widthFactor = 0.85, // 👈 controla ancho
    double heightFactor = 0.65, // 👈 controla alto
  }) {
    if (imagenUrl == null || imagenUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: Stack(
                  children: [
                    // Imagen
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3,
                        child: Image.network(
                          imagenUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),

                    // Botón cerrar
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagenPlaceholder(bool isDark) {
    return Center(
      child: SizedBox(
        height: 100, // 🔥 controla el alto total
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24), // 🔽 un poco menor
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.02),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.image_not_supported_rounded,
                size: 64, // 🔽 más pequeño
                color: isDark ? Colors.white30 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12), // 🔽 menos espacio
            Text(
              'Sin imagen disponible',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 13, // 🔽 texto más compacto
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNombreYPrecio(ThemeData theme, bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre del producto con efecto gradiente
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: isDark
                    ? [Colors.white, const Color.fromARGB(255, 255, 255, 255)]
                    : [const Color.fromARGB(255, 0, 0, 0), const Color.fromARGB(255, 0, 0, 0)],
              ).createShader(bounds),
              child: Text(
                widget.producto.nombre,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 0),
          ],
        ),
      ),
    );
  }

  //Widget Stock Info fondo cambia dependiendo del stock
  Widget _buildStockInfo(ThemeData theme, bool isDark) {
    final stockDisponible = widget.producto.stock > 0;
    final stockBajo = widget.producto.stock <= 10;

    // 🎨 Color del estado de stock (solo icono y badge)
    final Color stockColor = stockDisponible
        ? (stockBajo ? Colors.orange : const Color.fromARGB(255, 77, 132, 87))
        : Colors.red;

    // 🎭 Fondo por modo
    final Color backgroundColor = isDark
        ? Colors.black.withOpacity(0.25) // oscuro en modo oscuro
        : Colors.white.withOpacity(0.9); // claro en modo claro

    // ✏️ Color del texto descriptivo
    final Color textColor = isDark ? Colors.white : Colors.black;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔹 ICONO (solo cambia por stock)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                stockDisponible
                    ? (stockBajo
                          ? Icons.inventory_2_rounded
                          : Icons.check_circle_rounded)
                    : Icons.cancel_rounded,
                color: stockColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔖 BADGE (permanece con color del stock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stockDisponible
                          ? (stockBajo ? 'STOCK LIMITADO' : 'DISPONIBLE')
                          : 'AGOTADO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 📦 TEXTO DESCRIPTIVO (modo claro / oscuro)
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stockDisponible
                              ? '${widget.producto.stock} unidades disponibles'
                              : 'Sin stock disponible',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescripcion(ThemeData theme, bool isDark) {
    final descripcion =
        widget.producto.descripcion ?? 'Sin descripción disponible';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2E3440), const Color(0xFF1E2530)]
                : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                /* Container(    ICONO DE LA DESCRIPCIÓN (opcional) DEL PRODUCTO 
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ), */
                const SizedBox(width: 0),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isDark
                          ? [Colors.white, const Color.fromARGB(255, 255, 255, 255)]
                          : [const Color.fromARGB(255, 0, 0, 0), const Color.fromARGB(255, 0, 0, 0)],
                    ).createShader(bounds),
                    child: Text(
                      'Descripción del Producto',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            AnimatedCrossFade(
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    descripcion,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(255, 0, 0, 0),
                      height: 1.7,
                      letterSpacing: 0.3,
                      fontSize: 15,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 0),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.white10, Colors.white.withOpacity(0.05)]
                            : [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.02),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _descripcionExpandida = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver más',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 0),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    descripcion,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white70 : const Color.fromARGB(255, 0, 0, 0),
                      height: 1.7,
                      letterSpacing: 0.3,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.white10, Colors.white.withOpacity(0.05)]
                            : [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.02),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _descripcionExpandida = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver menos',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              crossFadeState: _descripcionExpandida
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  // TOTAL A PAGAR (solo texto, sin bloques)
  Widget _buildPrecioTotal(ThemeData theme, bool isDark) {
    final total = widget.producto.precio * _cantidad;
    final authService = Provider.of<AuthService>(context, listen: false);
    final estaLogueado = authService.estaLogueado;

    // 🎨 color del precio (puedes cambiarlo libremente)
    final Color precioColor = isDark
        ? const Color.fromARGB(255, 255, 255, 255) // rojo brillante oscuro
        : const Color.fromARGB(255, 14, 117, 0); // morado / rojo claro

    final Color textoColor = isDark ? Colors.white70 : Colors.black54;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🧾 TEXTO IZQUIERDO
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_rounded, size: 16, color: textoColor),
                const SizedBox(width: 6),
                Text(
                  'Total a pagar',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textoColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$_cantidad ${_cantidad == 1 ? 'unidad' : 'unidades'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textoColor.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // 💰 PRECIO (solo cambia el color)
        if (estaLogueado)
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: precioColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.4,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Inicia sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectorCantidad(ThemeData theme, bool isDark) {
    final stockDisponible = widget.producto.stock > 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1E2530), const Color(0xFF2E3440)]
              : [Colors.white, Colors.grey.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
            spreadRadius: 2,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 0, 0, 0),
                              const Color.fromARGB(255, 0, 0, 0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: isDark
                              ? [Colors.white, const Color.fromARGB(255, 255, 255, 255)]
                              : [const Color.fromARGB(255, 0, 0, 0), const Color.fromARGB(255, 0, 0, 0)],
                        ).createShader(bounds),
                        child: Text(
                          'Cantidad',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    // IZQUIERDA
                    Expanded(
                      flex: 4,
                      child: _invertido
                          ? _buildBotonAgregar(theme, isDark, stockDisponible)
                          : _buildSelectorCantidadInterno(
                              theme,
                              isDark,
                              stockDisponible,
                            ),
                    ),

                    const SizedBox(width: 8),

                    // 🔄 BOTÓN CENTRAL
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _invertido = !_invertido;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            size: 22,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // DERECHA
                    Expanded(
                      flex: 4,
                      child: _invertido
                          ? _buildSelectorCantidadInterno(
                              theme,
                              isDark,
                              stockDisponible,
                            )
                          : _buildBotonAgregar(theme, isDark, stockDisponible),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonMini({
    required IconData icon,
    VoidCallback? onPressed,
    required bool isDark,
  }) {
    final isEnabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ]
                    : [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.02),
                      ],
              )
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          splashColor: isEnabled
              ? (isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1))
              : Colors.transparent,
          highlightColor: isEnabled
              ? (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white24 : Colors.grey[400]),
            ),
          ),
        ),
      ),
    );
  }

  void _incrementarCantidad() {
    if (_cantidad < widget.producto.stock) {
      setState(() {
        _cantidad++;
      });
      // Pequeña animación de feedback
      _animationController.forward(from: 0.8);
    } else {
      CustomSnackBar.showWarning(
        context,
        'Stock máximo: ${widget.producto.stock}',
      );
    }
  }

  void _decrementarCantidad() {
    if (_cantidad > 1) {
      setState(() {
        _cantidad--;
      });
      // Pequeña animación de feedback
      _animationController.forward(from: 0.8);
    }
  }

  void _agregarAlCarrito() async {
    // Validar que esté logueado
    final authService = context.read<AuthService>();
    if (!authService.estaLogueado) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Sesión requerida'),
          content: const Text(
            'Debes iniciar sesión para agregar productos al carrito.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navegar a Mi Cuenta (pestaña 4)
                Navigator.pop(context);
              },
              child: const Text('Iniciar Sesión'),
            ),
          ],
        ),
      );
      return;
    }

    final carritoService = context.read<CarritoService>();

    // Validar stock
    final cantidadEnCarrito = carritoService.obtenerCantidadProducto(
      widget.producto.id,
    );
    if (cantidadEnCarrito + _cantidad > widget.producto.stock) {
      CustomSnackBar.showWarning(
        context,
        'No hay suficiente stock. Disponible: ${widget.producto.stock - cantidadEnCarrito}',
      );
      return;
    }

    // Agregar al carrito
    await carritoService.agregarProducto(widget.producto, cantidad: _cantidad);

    CustomSnackBar.showSuccess(
      context,
      '${widget.producto.nombre} x$_cantidad agregado al carrito',
    );

    // Resetear cantidad
    setState(() {
      _cantidad = 1;
    });
  }

  Widget _buildSelectorCantidadInterno(
    ThemeData theme,
    bool isDark,
    bool stockDisponible,
  ) {
    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            _buildBotonMini(
              icon: Icons.remove_rounded,
              onPressed: stockDisponible && _cantidad > 1
                  ? _decrementarCantidad
                  : null,
              isDark: isDark,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_cantidad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            _buildBotonMini(
              icon: Icons.add_rounded,
              onPressed: stockDisponible && _cantidad < widget.producto.stock
                  ? _incrementarCantidad
                  : null,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAgregar(
    ThemeData theme,
    bool isDark,
    bool stockDisponible,
  ) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: stockDisponible ? _agregarAlCarrito : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: stockDisponible
              ? Colors.green.shade600
              : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          stockDisponible ? 'AÑADIR' : 'SIN STOCK',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
