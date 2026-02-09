import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/carrito_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/producto.dart';
import '../../core/widgets/custom_overlay_notification.dart';
import '../../core/widgets/custom_confirm_dialog.dart';

class ProductosTab extends StatefulWidget {
  const ProductosTab({super.key});

  @override
  State<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<ProductosTab> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  List<Producto>? _productos;
  List<Producto>? _productosFiltrados;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productos = await _apiService.getProductos();
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filtrarProductos(String query) {
    if (_productos == null) return;

    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = _productos;
      } else {
        _productosFiltrados = _productos!.where((producto) {
          final nombre = producto.nombre.toLowerCase();
          final descripcion = producto.descripcion?.toLowerCase() ?? '';
          final busqueda = query.toLowerCase();

          return nombre.contains(busqueda) || descripcion.contains(busqueda);
        }).toList();
      }
    });
  }

  Future<void> _agregarAlCarrito(Producto producto) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.estaLogueado) {
      CustomOverlayNotification.showWarning(
        context,
        'Inicia sesión para agregar al carrito',
      );
      return;
    }

    final confirmar = await CustomConfirmDialog.show(
      context,
      title: '¿Agregar al carrito?',
      message: '¿Deseas agregar "${producto.nombre}" a tu carrito?',
      confirmText: 'Agregar',
      cancelText: 'Cancelar',
      icon: Icons.add_shopping_cart,
    );

    if (confirmar) {
      final carritoService = Provider.of<CarritoService>(
        context,
        listen: false,
      );
      await carritoService.agregarProducto(producto);

      if (mounted) {
        CustomOverlayNotification.showSuccess(
          context,
          '${producto.nombre} agregado al carrito',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final estaLogueado = authService.estaLogueado;

    return RefreshIndicator(
      onRefresh: _loadProductos,
      child: Column(
        children: [
          // Buscador
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProductos,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarProductos('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Lista de productos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
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
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadProductos,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _productosFiltrados == null || _productosFiltrados!.isEmpty
                ? const Center(child: Text('No hay productos'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _productosFiltrados!.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFiltrados![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Imagen del producto
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    producto.imagen != null &&
                                        producto.imagen!.isNotEmpty
                                    ? Image.network(
                                        producto.imagen!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.blue.shade100,
                                        child: Center(
                                          child: Text(
                                            producto.nombre
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),

                              // Información del producto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      producto.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (producto.descripcion != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        producto.descripcion!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Stock: ${producto.stock}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          producto.activo
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: producto.activo
                                              ? Colors.green
                                              : Colors.red,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Precio y botón
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Solo mostrar precio si está logueado
                                  if (estaLogueado)
                                    Text(
                                      '\$${producto.precio.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Inicia sesión',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  const SizedBox(height: 8),

                                  // Botón agregar al carrito
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _agregarAlCarrito(producto),
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 16,
                                    ),
                                    label: const Text('Agregar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromRGBO(
                                        11,
                                        15,
                                        24,
                                        1,
                                      ),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
