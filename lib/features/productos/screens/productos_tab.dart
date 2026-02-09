import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/productos_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../models/producto.dart';
import '../../../models/categoria.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/widgets/custom_confirm_dialog.dart';
import '../../../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

/// Clase pública para compartir el filtro de categoría entre pantallas
class ProductosFiltro {
  static int? categoriaSeleccionada;
}

class ProductosTab extends StatefulWidget {
  const ProductosTab({super.key});

  @override
  State<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<ProductosTab>
    with RouteAware, WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _queryBusqueda = '';

  // Filtros
  List<Categoria> _categorias = [];
  int? _categoriaSeleccionada;
  String? _rangoPrecios; // 'todos', '10-20', '20-50', '50-100', '100+'

  // Paginación
  int _paginaActual = 1;
  final int _productosPorPagina = 10;

  @override
  void initState() {
    super.initState();
    // Cargar productos al iniciar si está vacío
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final productosService = Provider.of<ProductosService>(
        context,
        listen: false,
      );
      if (productosService.productos.isEmpty) {
        productosService.fetchProductos();
      }

      // Cargar categorías
      _cargarCategorias();
    });
    // Escuchar ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _cargarCategorias() async {
    try {
      final apiService = ApiService();
      final categorias = await apiService.obtenerCategorias();
      if (mounted) {
        setState(() {
          _categorias = categorias.where((c) => c.activo).toList();
        });

        // Aplicar filtro de categoría si viene desde otra pantalla
        // Hacerlo aquí asegura que las categorías ya estén cargadas
        if (ProductosFiltro.categoriaSeleccionada != null) {
          setState(() {
            _categoriaSeleccionada = ProductosFiltro.categoriaSeleccionada;
            ProductosFiltro.categoriaSeleccionada = null;
          });
          _aplicarFiltros();
        }
      }
    } catch (e) {
      // Error silencioso al cargar categorías
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (mounted) {
      _refreshProductos();
      // Aplicar filtro si viene desde otra pantalla
      if (ProductosFiltro.categoriaSeleccionada != null) {
        setState(() {
          _categoriaSeleccionada = ProductosFiltro.categoriaSeleccionada;
          ProductosFiltro.categoriaSeleccionada = null;
        });
        _aplicarFiltros();
      }
    }
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
    // Simplemente refrescar todos los productos
    // Los filtros se aplican localmente en el build
    productosService.fetchProductos();
  }

  void _filtrarProductos(String query) {
    setState(() {
      _queryBusqueda = query;
      _paginaActual = 1; // Reiniciar a página 1 al buscar
    });
  }

  void _aplicarFiltros() {
    setState(() {
      _paginaActual = 1; // Reiniciar a página 1 al aplicar filtros
    });

    if (kDebugMode) {
      print('🔍 Filtro local de categoría: $_categoriaSeleccionada');
      print('💰 Filtro local de precio: $_rangoPrecios');
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _categoriaSeleccionada = null;
      _rangoPrecios = null;
      _paginaActual = 1;
    });
  }

  Future<void> _agregarAlCarrito(Producto producto) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final productosService = Provider.of<ProductosService>(
      context,
      listen: false,
    );

    if (!authService.estaLogueado) {
      CustomOverlayNotification.showWarning(
        context,
        'Inicia sesión para agregar al carrito',
      );
      return;
    }
    // 🔥 VALIDACIÓN DE STOCK CRÍTICA
    if (producto.stock <= 0) {
      CustomOverlayNotification.showError(
        context,
        '${producto.nombre} está AGOTADO',
      );
      return;
    }

    if (!producto.activo) {
      CustomOverlayNotification.showWarning(
        context,
        'Este producto no está disponible',
      );
      return;
    }

    // Implementación del diálogo respetando el tema
    final confirmar = await CustomConfirmDialog.show(
      context,
      title: '¿Agregar al carrito?',
      message:
          '¿Deseas agregar "${producto.nombre}" a tu carrito?\n\nStock disponible: ${producto.stock}',
      confirmText: 'Agregar',
      cancelText: 'Cancelar',
      icon: Icons.add_shopping_cart,
      // Eliminamos primaryColor e isDarkMode ya que no existen en tu definición
    );

    if (!mounted) return;

    if (confirmar) {
      final carritoService = Provider.of<CarritoService>(
        context,
        listen: false,
      );

      final agregado = await carritoService.agregarProducto(producto);

      if (mounted) {
        if (agregado) {
          CustomOverlayNotification.showSuccess(
            context,
            '${producto.nombre} agregado al carrito',
          );
        } else {
          CustomOverlayNotification.showError(
            context,
            'No hay suficiente stock disponible',
          );
          productosService.fetchProductos();
        }
      }
    }
  }

  void _navegarADetalle(Producto producto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductoDetalleScreen(producto: producto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final productosService = Provider.of<ProductosService>(context);
    final estaLogueado = authService.estaLogueado;

    // 1. Obtener TODOS los productos activos del servicio
    List<Producto> productos = productosService.productosActivos;

    // 2. Aplicar filtro de categoría localmente
    if (_categoriaSeleccionada != null) {
      productos = productos
          .where((p) => p.categoriaId == _categoriaSeleccionada)
          .toList();
    }

    // 3. Aplicar búsqueda de texto localmente
    if (_queryBusqueda.isNotEmpty) {
      final queryLower = _queryBusqueda.toLowerCase();
      productos = productos.where((producto) {
        final nombre = producto.nombre.toLowerCase();
        final descripcion = producto.descripcion?.toLowerCase() ?? '';
        return nombre.contains(queryLower) || descripcion.contains(queryLower);
      }).toList();
    }

    // 4. Aplicar filtro de precio localmente (DESPUÉS de la búsqueda)
    if (_rangoPrecios != null && _rangoPrecios != 'todos') {
      double? precioMin;
      double? precioMax;

      switch (_rangoPrecios) {
        case '10-20':
          precioMin = 10;
          precioMax = 20;
          break;
        case '20-50':
          precioMin = 20;
          precioMax = 50;
          break;
        case '50-100':
          precioMin = 50;
          precioMax = 100;
          break;
        case '100+':
          precioMin = 100;
          precioMax = null;
          break;
      }

      productos = productos.where((p) {
        if (precioMin != null && p.precio < precioMin) return false;
        if (precioMax != null && p.precio > precioMax) return false;
        return true;
      }).toList();
    }

    // 5. Los productos ya están filtrados
    final productosFiltrados = productos;

    // 5. Aplicar paginación
    final totalProductos = productosFiltrados.length;
    final totalPaginas = (totalProductos / _productosPorPagina).ceil();
    final startIndex = (_paginaActual - 1) * _productosPorPagina;
    final endIndex = (startIndex + _productosPorPagina).clamp(
      0,
      totalProductos,
    );
    final productosPaginados = startIndex < totalProductos
        ? productosFiltrados.sublist(startIndex, endIndex)
        : <Producto>[];

    // Debug para verificar productos
    if (kDebugMode) {
      print('📊 Total productos filtrados: $totalProductos');
      print('📄 Total páginas: $totalPaginas');
      print('📍 Página actual: $_paginaActual');
      print('🔢 Productos por página: $_productosPorPagina');
    }

    // ... dentro del método build ...

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => productosService.fetchProductos(),
      child: Column(
        children: [
          // Buscador Dinámico con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1C1E), const Color(0xFF2D3748)]
                    : [Colors.grey.shade50, Colors.grey.shade100],
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ), //Tamaño buscador margenes
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filtrarProductos,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black45,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(5), //Margen dentro buscador
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.24),
                                Colors.white.withValues(alpha: 0.10),
                              ]
                            : [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filtrarProductos('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black26,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2E3440) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 5, //Tamaño del texto dentro del buscador
                    vertical: 5,
                  ),
                ),
              ),
            ),
          ),

          // Filtros con diseño mejorado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1C1E), const Color(0xFF252A35)]
                    : [Colors.grey.shade100, Colors.grey.shade50],
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 1, //Espacio sentrado al los lados de precio categoria
              vertical: 5,
            ), // Espaciado ajustado
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    if (_categoriaSeleccionada != null || _rangoPrecios != null)
                      TextButton.icon(
                        onPressed: _limpiarFiltros,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white70
                              : Colors.black54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8), // Espacio entre filas
                Row(
                  children: [
                    // Filtro de Categoría
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<int>(
                          isExpanded:
                              true, // 1. CORRECCIÓN: Obliga al contenido a quedarse dentro del Expanded
                          value: _categoriaSeleccionada ?? -1,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            prefixIcon: Icon(
                              Icons.category_rounded,
                              size: 18,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white30 : Colors.black26,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal:
                                  8, // 2. CORRECCIÓN: Un poco menos de espacio ayuda en pantallas pequeñas
                              vertical:
                                  10, // Ajuste vertical para mejor apariencia
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2E3440)
                                : Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: -1,
                              child: Text(
                                'Todas',
                                overflow: TextOverflow.ellipsis,
                              ), // 3. CORRECCIÓN: Previene overflow en el texto
                            ),
                            ..._categorias.map((categoria) {
                              return DropdownMenuItem<int>(
                                value: categoria.id,
                                child: Text(
                                  categoria.nombre,
                                  overflow: TextOverflow
                                      .ellipsis, // Previene overflow si el nombre es muy largo
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _categoriaSeleccionada = value == -1
                                  ? null
                                  : value;
                            });
                            _aplicarFiltros();
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Filtro de Precio
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          isExpanded:
                              true, // 1. CORRECCIÓN: Muy importante aquí también
                          value: _rangoPrecios ?? 'todos',
                          isDense: true,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Precio',
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            prefixIcon: Icon(
                              Icons.attach_money_rounded,
                              size: 18,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white30 : Colors.black26,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal:
                                  8, // 2. CORRECCIÓN //movimiento palabras precio categoria
                              vertical: 10, // Ajuste vertical
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2E3440)
                                : Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'todos',
                              child: Text(
                                'Todos',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: '10-20',
                              child: Text(
                                '\$10-\$20',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: '20-50',
                              child: Text(
                                '\$20-\$50',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: '50-100',
                              child: Text(
                                '\$50-\$100',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem<String>(
                              //8 espacios
                              value: '100+',
                              child: Text(
                                '\$100+',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _rangoPrecios = value == 'todos' ? null : value;
                            });
                            _aplicarFiltros();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ... resto del código (Lista de productos)
          // Lista de productos
          Expanded(
            child: productosService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : productosService.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            productosService.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => productosService.fetchProductos(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : productosFiltrados.isEmpty
                ? const Center(child: Text('No hay productos'))
                : Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.65,
                              ),
                          itemCount: productosPaginados.length,
                          itemBuilder: (context, index) {
                            final producto = productosPaginados[index];
                            final sinStock = producto.stock <= 0;

                            return AnimatedOpacity(
                              opacity: sinStock ? 0.85 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? const [
                                            Color(0xFF2E3440),
                                            Color(0xFF1E2530),
                                          ]
                                        : [Colors.white, Colors.grey.shade50],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.08),
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
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _navegarADetalle(producto),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          //En este apartado vamos a continuar con lo siguiente
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              /// IMAGEN
                                              Hero(
                                                tag: 'producto_${producto.id}',
                                                child: Container(
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: isDark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.15,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child:
                                                        producto.imagen !=
                                                                null &&
                                                            producto
                                                                .imagen!
                                                                .isNotEmpty
                                                        ? Image.network(
                                                            producto.imagen!,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) {
                                                              return const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                size: 30,
                                                              );
                                                            },
                                                          )
                                                        : Container(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            child: Center(
                                                              child: Text(
                                                                producto.nombre
                                                                    .substring(
                                                                      0,
                                                                      1,
                                                                    )
                                                                    .toUpperCase(),
                                                                style: TextStyle(
                                                                  fontSize: 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDark
                                                                      ? Colors
                                                                            .white70
                                                                      : Colors
                                                                            .black54,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(height: 10),

                                              /// NOMBRE
                                              Text(
                                                producto.nombre,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),

                                              const SizedBox(height: 6),

                                              /// CATEGORÍA
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white
                                                            .withOpacity(0.08)
                                                      : Colors.black
                                                            .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  producto.categoriaNombre,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.black54,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              /// STOCK
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.inventory_2_rounded,
                                                    size: 12,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Stock: ${producto.stock}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 8),

                                              /// PRECIO / LOGIN
                                              if (estaLogueado) ...[
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: [
                                                              Color(0xFF10B981),
                                                              Color(0xFF059669),
                                                            ],
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            100,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '\$${producto.precio.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ] else ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withOpacity(0.1)
                                                        : Colors.black
                                                              .withOpacity(
                                                                0.05,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '🔒 Inicia sesión',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isDark
                                                          ? Colors.white60
                                                          : Colors.black45,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        /// BADGE AGOTADO
                                        if (sinStock)
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'AGOTADO',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                        ),
                      ),
                      // Controles de paginación mejorados
                      if (totalPaginas > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, //Tamaño alto de paginacion
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      const Color(0xFF1A1C1E),
                                      const Color(0xFF252A35),
                                    ]
                                  : [Colors.grey.shade50, Colors.grey.shade100],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              // Botón anterior
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _paginaActual > 1
                                      ? LinearGradient(
                                          colors: isDark
                                              ? [
                                                  Colors.white12,
                                                  Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                                ]
                                              : [
                                                  Colors.black12,
                                                  Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                                ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(
                                            _paginaActual > 1 ? 0.2 : 0.05,
                                          )
                                        : Colors.black.withOpacity(
                                            _paginaActual > 1 ? 0.2 : 0.05,
                                          ),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _paginaActual > 1
                                      ? () => setState(() => _paginaActual--)
                                      : null,
                                  icon: Icon(
                                    Icons.chevron_left_rounded,
                                    color: _paginaActual > 1
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.white24
                                              : Colors.black26),
                                  ),
                                  tooltip: 'Página anterior',
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Indicador de página
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF2E3440),
                                            const Color(0xFF3B4252),
                                          ]
                                        : [Colors.white, Colors.grey.shade50],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.library_books_rounded,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      '$_paginaActual/$totalPaginas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Botón siguiente
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _paginaActual < totalPaginas
                                      ? LinearGradient(
                                          colors: isDark
                                              ? [
                                                  Colors.white12,
                                                  Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                                ]
                                              : [
                                                  Colors.black12,
                                                  Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                                ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(
                                            _paginaActual < totalPaginas
                                                ? 0.2
                                                : 0.05,
                                          )
                                        : Colors.black.withOpacity(
                                            _paginaActual < totalPaginas
                                                ? 0.2
                                                : 0.05,
                                          ),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _paginaActual < totalPaginas
                                      ? () => setState(() => _paginaActual++)
                                      : null,
                                  icon: Icon(
                                    Icons.chevron_right_rounded,
                                    color: _paginaActual < totalPaginas
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.white24
                                              : Colors.black26),
                                  ),
                                  tooltip: 'Página siguiente',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
