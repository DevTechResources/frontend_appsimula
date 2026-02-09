import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';
import '../core/services/carrito_service.dart';
import '../core/services/auth_service.dart';
import '../models/producto.dart';
import '../models/cliente.dart';
import '../core/widgets/custom_overlay_notification.dart';
import '../core/widgets/custom_confirm_dialog.dart';
import '../features/carrito/screens/carrito_screen.dart';
import '../features/productos/screens/producto_detalle_screen.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _apiService = ApiService();
  List<Producto>? _productos;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productos = await _apiService.getProductos();
      setState(() {
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _mostrarLoginDialog() {
    final emailController = TextEditingController(
      text: 'admin@techsolutions.com',
    );
    final passwordController = TextEditingController(text: 'password123');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Sesión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inicia sesión para ver precios y añadir al carrito'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await _apiService.login(
                  emailController.text,
                  passwordController.text,
                );
                if (mounted) {
                  // Actualizar AuthService
                  final cliente = Cliente.fromJson(response['cliente']);
                  Provider.of<AuthService>(
                    context,
                    listen: false,
                  ).setCliente(cliente);

                  Navigator.pop(context);
                  CustomOverlayNotification.showSuccess(
                    context,
                    'Sesión iniciada correctamente',
                  );
                }
              } catch (e) {
                if (mounted) {
                  CustomOverlayNotification.showError(
                    context,
                    'Error al iniciar sesión: ${e.toString().replaceAll("Exception:", "").trim()}',
                  );
                }
              }
            },
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carritoService = Provider.of<CarritoService>(context);
    final authService = Provider.of<AuthService>(context);
    final isLoggedIn = authService.estaLogueado;

    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $_errorMessage'),
                    ElevatedButton(
                      onPressed: _loadProductos,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProductos,
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _productos?.length ?? 0,
                  itemBuilder: (context, index) {
                    final producto = _productos![index];
                    return _ProductoCard(
                      producto: producto,
                      isLoggedIn: isLoggedIn,
                      onLoginRequired: _mostrarLoginDialog,
                      onAgregarCarrito: () async {
                        final confirmar = await CustomConfirmDialog.show(
                          context,
                          title: 'Agregar al carrito',
                          message:
                              '¿Deseas agregar ${producto.nombre} al carrito?',
                          confirmText: 'Agregar',
                          cancelText: 'Cancelar',
                          icon: Icons.add_shopping_cart,
                        );

                        if (confirmar && context.mounted) {
                          await carritoService.agregarProducto(producto);
                          CustomOverlayNotification.showSuccess(
                            context,
                            '✅ ${producto.nombre} añadido al carrito',
                          );
                        }
                      },
                    );
                  },
                ),
              ),
        // Botón flotante de carrito
        if (isLoggedIn && carritoService.cantidadTotal > 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CarritoScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: Text('${carritoService.cantidadTotal}'),
              backgroundColor: const Color.fromARGB(255, 102, 147, 60),
            ),
          ),
      ],
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;
  final VoidCallback onAgregarCarrito;

  const _ProductoCard({
    required this.producto,
    required this.isLoggedIn,
    required this.onLoginRequired,
    required this.onAgregarCarrito,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navegar al detalle del producto
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductoDetalleScreen(producto: producto),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen del producto con Hero animation
            Expanded(
              flex: 3,
              child: Hero(
                tag: 'producto_${producto.id}',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: producto.imagen != null
                      ? Image.network(
                          producto.imagen!,
                          fit: BoxFit.cover,
                          cacheWidth:
                              400, // ✅ Optimización: redimensiona antes de cachear
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.inventory_2,
                                size: 64,
                                color: Colors.grey,
                              ),
                        )
                      : const Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.grey,
                        ),
                ),
              ),
            ),
            // Información del producto
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (producto.descripcion != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        producto.descripcion!,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    // Precio (solo visible si está logueado)
                    if (isLoggedIn)
                      Text(
                        '\$${producto.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Inicia sesión para ver precio',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Botón añadir al carrito
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: isLoggedIn ? onAgregarCarrito : onLoginRequired,
                icon: Icon(
                  isLoggedIn ? Icons.add_shopping_cart : Icons.lock,
                  size: 16,
                ),
                label: Text(
                  isLoggedIn ? 'Añadir' : 'Iniciar sesión',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLoggedIn ? Colors.blue : Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
