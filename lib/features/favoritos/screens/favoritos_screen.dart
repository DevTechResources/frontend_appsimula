import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../models/producto.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar favoritos al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FavoritosService>(context, listen: false).fetchFavoritos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoritosService = Provider.of<FavoritosService>(context);
    final carritoService = Provider.of<CarritoService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Favoritos'), centerTitle: true),
      body: favoritosService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoritosService.favoritos.isEmpty
          ? _buildEmptyState()
          : _buildFavoritosList(favoritosService, carritoService),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 100, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tienes favoritos aún',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Desliza productos en el carrito para agregarlos',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritosList(
    FavoritosService favoritosService,
    CarritoService carritoService,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favoritosService.favoritos.length,
      itemBuilder: (context, index) {
        final producto = favoritosService.favoritos[index];
        return _buildFavoritoCard(producto, favoritosService, carritoService);
      },
    );
  }

  Widget _buildFavoritoCard(
    Producto producto,
    FavoritosService favoritosService,
    CarritoService carritoService,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen del producto
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: producto.imagen != null
                  ? Image.network(
                      producto.imagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.inventory_2, color: Colors.grey),
                    )
                  : const Icon(Icons.inventory_2, color: Colors.grey),
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
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${producto.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${producto.stock}',
                    style: TextStyle(
                      color: producto.stock > 0 ? Colors.grey : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Botones de acción
            Container(
              constraints: const BoxConstraints(minWidth: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón eliminar de favoritos
                  IconButton(
                    onPressed: () async {
                      final success = await favoritosService.eliminarFavorito(
                        producto.id,
                      );
                      if (success && mounted) {
                        CustomOverlayNotification.showInfo(
                          context,
                          'Eliminado de favoritos',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.favorite,
                      color: Colors.pinkAccent,
                      size: 22,
                    ),
                    tooltip: 'Quitar de favoritos',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  // Botón agregar al carrito
                  IconButton(
                    onPressed: producto.stock > 0
                        ? () async {
                            final agregado = await carritoService
                                .agregarProducto(producto, cantidad: 1);
                            if (agregado) {
                              CustomOverlayNotification.showSuccess(
                                context,
                                'Agregado al carrito',
                              );
                            } else {
                              CustomOverlayNotification.showError(
                                context,
                                'Sin stock disponible',
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 22),
                    color: Colors.blue,
                    tooltip: 'Agregar al carrito',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
