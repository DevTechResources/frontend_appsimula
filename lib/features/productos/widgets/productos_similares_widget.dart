import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../models/producto.dart';
import '../../../theme/app_theme.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../screens/main_screen.dart';
import '../screens/producto_detalle_screen.dart';
import '../screens/productos_tab.dart';

class ProductosSimilaresWidget extends StatefulWidget {
  final int productoId;
  final int categoriaId;
  final int limit;

  const ProductosSimilaresWidget({
    super.key,
    required this.productoId,
    required this.categoriaId,
    this.limit = 5,
  });

  @override
  State<ProductosSimilaresWidget> createState() =>
      _ProductosSimilaresWidgetState();
}

class _ProductosSimilaresWidgetState extends State<ProductosSimilaresWidget> {
  final ApiService _apiService = ApiService();
  List<Producto> _similares = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSimilares();
  }

  Future<void> _cargarSimilares() async {
    if (!mounted) return;

    try {
      final response = await _apiService.get(
        '/productos/${widget.productoId}/similares?limit=${widget.limit}',
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _similares = data.map((json) => Producto.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Error al cargar productos similares';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error cargando productos similares: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar productos similares';
          _isLoading = false;
        });
      }
    }
  }

  void _navegarAProductosFiltrados(BuildContext context) {
    // Establecer el filtro de categoría usando la clase pública
    ProductosFiltro.categoriaSeleccionada = widget.categoriaId;

    // Cerrar la pantalla de detalles del producto
    Navigator.of(context).pop();

    // Navegar a la pestaña de productos (sin usar DefaultTabController)
    // Usar el método estático de MainScreen para cambiar de pestaña
    Future.delayed(const Duration(milliseconds: 100), () {
      // Importar main_screen para usar el método estático
      MainScreenState.cambiarPestanaGlobal(1); // 1 = Productos
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _similares.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(10),

            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 28, 49, 96),
                        const Color.fromARGB(255, 28, 49, 96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(
                          255,
                          45,
                          51,
                          92,
                        ).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.recommend_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isDark
                          ? [Colors.white, Colors.white70]
                          : [Colors.black87, Colors.black54],
                    ).createShader(bounds),
                    child: Text(
                      'Similares',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _similares.length + 1, // +1 para la tarjeta "VER MÁS"
            itemBuilder: (context, index) {
              // Si es el último índice, mostrar tarjeta "VER MÁS"
              if (index == _similares.length) {
                return _VerMasCard(
                  onTap: () => _navegarAProductosFiltrados(context),
                  isDark: isDark,
                );
              }
              return _ProductoSimilarCard(producto: _similares[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _ProductoSimilarCard extends StatelessWidget {
  final Producto producto;

  const _ProductoSimilarCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallPhone = screenHeight < 700;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductoDetalleScreen(producto: producto),
        ),
      ),
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 6),
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
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: producto.imagen != null && producto.imagen!.isNotEmpty
                      ? Image.network(
                          producto.imagen!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 340,
                          filterQuality: FilterQuality.low,

                          errorBuilder: (context, _, __) =>
                              _buildImagenPlaceholder(),
                        )
                      : _buildImagenPlaceholder(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    radius: 18,
                    child: Consumer<FavoritosService>(
                      builder: (context, favoritosService, _) {
                        final isFavorite = favoritosService.esFavorito(
                          producto.id,
                        );
                        return IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          onPressed: () => _toggleFavorito(context),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? Colors.pinkAccent
                                : Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              fit: FlexFit.tight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🏷️ Nombre
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),

                    // 💰 Precio + 📦 Stock (bloque compacto)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${producto.precio.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5, // 👈 antes 14–15
                            height: 1.1, // 👈 reduce altura real
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 2),
                        Text(
                          producto.stock > 0 ? 'En stock' : 'Sin stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: producto.stock > 0
                                ? const Color.fromARGB(255, 0, 133, 69)
                                : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallPhone ? 10 : 10.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: producto.stock > 0
                      ? () => _agregarAlCarrito(context)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: producto.stock > 0
                        ? Colors.green
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    producto.stock > 0 ? 'AGREGAR' : 'SIN STOCK',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagenPlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          size: 36,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _toggleFavorito(BuildContext context) async {
    final authService = context.read<AuthService>();
    if (!authService.estaLogueado) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Sesión requerida'),
          content: const Text(
            'Debes iniciar sesión para agregar productos a favoritos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    final favoritosService = context.read<FavoritosService>();
    if (favoritosService.esFavorito(producto.id)) {
      await favoritosService.eliminarFavorito(producto.id);
      CustomSnackBar.showInfo(context, 'Eliminado de favoritos');
    } else {
      await favoritosService.agregarFavorito(producto);
      CustomSnackBar.showSuccess(context, 'Agregado a favoritos');
    }
  }

  void _agregarAlCarrito(BuildContext context) async {
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
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    final carritoService = context.read<CarritoService>();
    final cantidadEnCarrito = carritoService.obtenerCantidadProducto(
      producto.id,
    );
    if (cantidadEnCarrito + 1 > producto.stock) {
      CustomSnackBar.showWarning(context, 'No hay suficiente stock disponible');
      return;
    }

    await carritoService.agregarProducto(producto, cantidad: 1);
    CustomSnackBar.showSuccess(
      context,
      '${producto.nombre} agregado al carrito',
    );
  }
}

/// Widget de tarjeta "VER MÁS" que ocupa el mismo espacio que un producto similar
class _VerMasCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _VerMasCard({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color.fromARGB(255, 0, 0, 0),
                    const Color.fromARGB(255, 0, 0, 0),
                    const Color.fromARGB(255, 0, 0, 0),
                  ]
                : [
                    const Color.fromARGB(255, 0, 0, 0),
                    const Color.fromARGB(255, 0, 0, 0),
                    const Color.fromARGB(255, 0, 0, 0),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.15),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.9)],
              ).createShader(bounds),
              child: Text(
                'VER MÁS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Explorar similares',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
