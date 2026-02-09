import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/carrito_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/productos_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/favoritos_service.dart';
import '../../../core/services/datos_facturacion_service.dart';
import '../../../core/services/direcciones_envio_service.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/custom_confirm_dialog.dart';
import '../../productos/screens/producto_detalle_screen.dart';
import 'checkout_screen.dart';
import '../../../screens/main_screen.dart';

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  Future<void> _realizarPedido(BuildContext context) async {
    final carritoService = Provider.of<CarritoService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final datosFactService = Provider.of<DatosFacturacionService>(
      context,
      listen: false,
    );
    final direccionesService = Provider.of<DireccionesEnvioService>(
      context,
      listen: false,
    );

    if (!authService.estaLogueado) {
      CustomOverlayNotification.showWarning(
        context,
        'Debes iniciar sesión para realizar un pedido',
      );
      return;
    }

    if (carritoService.items.isEmpty) {
      CustomOverlayNotification.showWarning(context, 'El carrito está vacío');
      return;
    }

    // ✅ VERIFICAR QUE TENGA DATOS DE FACTURACIÓN Y DIRECCIÓN
    if (datosFactService.datos.isEmpty) {
      final irAgregar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Datos de Facturación'),
          content: const Text(
            'Necesitas agregar al menos un dato de facturación antes de realizar un pedido.\n\n¿Deseas agregar ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      );

      if (irAgregar == true && context.mounted) {
        await Navigator.pushNamed(context, '/datos-facturacion');
        return;
      }
      return;
    }

    if (direccionesService.direcciones.isEmpty) {
      final irAgregar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Dirección de Envío'),
          content: const Text(
            'Necesitas agregar al menos una dirección de envío antes de realizar un pedido.\n\n¿Deseas agregar ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      );

      if (irAgregar == true && context.mounted) {
        await Navigator.pushNamed(context, '/direcciones-envio');
        return;
      }
      return;
    }

    // 📋 NAVEGAR A PANTALLA DE CHECKOUT PARA SELECCIONAR DATOS
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );

    // Si el usuario canceló, no hacer nada
    if (resultado == null || !context.mounted) return;

    final datosFacturacionId = resultado['datosFacturacion']?.id;
    final direccionEnvioId = resultado['direccionEnvio']?.id;

    if (datosFacturacionId == null || direccionEnvioId == null) {
      CustomOverlayNotification.showError(
        context,
        'Debes seleccionar datos de facturación y dirección',
      );
      return;
    }

    // 🔥 CREAR PEDIDO CON LOS DATOS SELECCIONADOS
    final productosService = Provider.of<ProductosService>(
      context,
      listen: false,
    );
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );
    final apiService = ApiService();

    try {
      // Preparar productos del carrito
      final productos = carritoService.items.map((item) {
        return {'id': item.producto.id, 'cantidad': item.cantidad};
      }).toList();

      // Crear pedido y factura CON DATOS SELECCIONADOS
      final resultadoPedido = await apiService.crearPedidoDesdeCarrito(
        clienteId: authService.clienteActual!.id,
        productos: productos,
        datosFacturacionId: datosFacturacionId,
        direccionEnvioId: direccionEnvioId,
      );

      if (context.mounted) {
        // 🔥 PASO 1: Vaciar carrito (sincroniza con backend)
        await carritoService.vaciarCarrito();

        // 🔥 PASO 2: Actualizar productos desde el backend
        await productosService.fetchProductos();

        // 🔥 PASO 3: Actualizar facturas para reflejar la nueva factura
        await facturasService.fetchFacturas(
          clienteId: authService.clienteActual?.id,
          esAdmin: authService.esInstalador,
        );

        // 🔥 PASO 4: Actualizar crédito del cliente
        try {
          final creditoActualizado = await apiService.obtenerCreditoCliente(
            authService.clienteActual!.id,
          );

          // Actualizar el cliente actual con nuevos valores de crédito
          final clienteActualizado = authService.clienteActual!.copyWith(
            cupoCredito:
                double.tryParse(
                  creditoActualizado['cupo_credito_total'].toString(),
                ) ??
                0,
            cupoUtilizado:
                double.tryParse(
                  creditoActualizado['cupo_utilizado'].toString(),
                ) ??
                0,
            saldoDisponible:
                double.tryParse(
                  creditoActualizado['saldo_disponible'].toString(),
                ) ??
                0,
            valorVencido:
                double.tryParse(
                  creditoActualizado['valor_vencido'].toString(),
                ) ??
                0,
            diasPlazo:
                int.tryParse(creditoActualizado['dias_plazo'].toString()) ?? 0,
          );

          // Usar setCliente para actualizar y notificar listeners
          authService.setCliente(clienteActualizado);

          print('💳 Crédito actualizado en AuthService:');
          print('   - Utilizado: \$${clienteActualizado.cupoUtilizado}');
          print('   - Disponible: \$${clienteActualizado.saldoDisponible}');
        } catch (creditoError) {
          print('⚠️ No se pudo actualizar crédito: $creditoError');
        }

        // 🔥 PASO 5: Mostrar éxito con SnackBar
        CustomSnackBar.showSuccess(
          context,
          'Pedido creado exitosamente. Factura #${resultadoPedido['factura']['numero_factura']}',
        );

        CustomOverlayNotification.showSuccess(context, '¡Pedido confirmado!');

        print('✅ Carrito vaciado, productos, facturas y crédito actualizados');
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.showError(
          context,
          'Error al crear pedido: ${e.toString().replaceAll("Exception:", "").trim()}',
        );

        CustomOverlayNotification.showError(
          context,
          'No se pudo crear el pedido',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carritoService = Provider.of<CarritoService>(context);
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Si no está logueado, mostrar pantalla de login
    if (!authService.estaLogueado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carrito de Compras')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 100,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'Para ver tu carrito de compras debes iniciar sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Accede a tu cuenta para gestionar tus productos favoritos y realizar pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    MainScreenState.cambiarPestanaGlobal(4); // 👈 MI CUENTA
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B0F18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        actions: [
          if (carritoService.items.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vaciar carrito'),
                    content: const Text('¿Estás seguro de vaciar el carrito?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await carritoService.vaciarCarrito();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Vaciar'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text(
                'Vaciar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: carritoService.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: carritoService.items.length,
                    itemBuilder: (context, index) {
                      final item = carritoService.items[index];

                      return Consumer<FavoritosService>(
                        builder: (context, favoritosService, child) {
                          final yaEsFavorito = favoritosService.esFavorito(
                            item.producto.id,
                          );

                          return Dismissible(
                            key: ValueKey(item.producto.id),

                            // 💗 FAVORITOS (izquierda → derecha)
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: yaEsFavorito
                                    ? Colors.orange
                                    : Colors.pinkAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    yaEsFavorito
                                        ? Icons.heart_broken
                                        : Icons.favorite_border,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    yaEsFavorito
                                        ? 'Eliminar de favoritos'
                                        : 'Agregar a favoritos',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 🗑️ ELIMINAR (derecha → izquierda)
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.delete, color: Colors.white),
                                ],
                              ),
                            ),

                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // 🗑️ Confirmar eliminación
                                return await CustomConfirmDialog.showDelete(
                                  context,
                                  itemName: item.producto.nombre,
                                  type: 'producto del carrito',
                                );
                              } else {
                                // 💗 Verificar si ya está en favoritos
                                final favoritosService =
                                    Provider.of<FavoritosService>(
                                      context,
                                      listen: false,
                                    );

                                final yaEsFavorito = favoritosService
                                    .esFavorito(item.producto.id);

                                if (yaEsFavorito) {
                                  // Confirmar eliminación de favoritos
                                  final confirmarEliminar = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        '¿Eliminar de favoritos?',
                                      ),
                                      content: Text(
                                        '¿Deseas eliminar "${item.producto.nombre}" de tu lista de favoritos?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                          ),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmarEliminar == true) {
                                    final success = await favoritosService
                                        .eliminarFavorito(item.producto.id);

                                    if (context.mounted && success) {
                                      CustomOverlayNotification.showInfo(
                                        context,
                                        '${item.producto.nombre} eliminado de favoritos',
                                      );
                                    }
                                  }
                                } else {
                                  // Agregar a favoritos
                                  final success = await favoritosService
                                      .agregarFavorito(item.producto);

                                  if (context.mounted) {
                                    if (success) {
                                      CustomOverlayNotification.showSuccess(
                                        context,
                                        '${item.producto.nombre} agregado a favoritos ❤️',
                                      );
                                    } else {
                                      CustomOverlayNotification.showError(
                                        context,
                                        'Error al agregar a favoritos',
                                      );
                                    }
                                  }
                                }
                                return false; // NO se elimina del carrito
                              }
                            },

                            onDismissed: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                await carritoService.eliminarItem(
                                  item.producto.id,
                                );
                                if (context.mounted) {
                                  CustomOverlayNotification.showInfo(
                                    context,
                                    '${item.producto.nombre} eliminado del carrito',
                                  );
                                }
                              }
                            },

                            child: InkWell(
                              onTap: () {
                                // Abrir detalle del producto
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductoDetalleScreen(
                                      producto: item.producto,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Imagen
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: item.producto.imagen != null
                                            ? Image.network(
                                                item.producto.imagen!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons.inventory_2,
                                                      color: Colors.grey,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.inventory_2,
                                                color: Colors.grey,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.producto.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '\$${item.producto.precio.toStringAsFixed(2)} c/u',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Controles de cantidad
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 120,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () async {
                                                    await carritoService
                                                        .actualizarCantidad(
                                                          item.producto.id,
                                                          item.cantidad - 1,
                                                        );
                                                  },
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                  iconSize: 24,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: Text(
                                                    '${item.cantidad}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () async {
                                                    await carritoService
                                                        .actualizarCantidad(
                                                          item.producto.id,
                                                          item.cantidad + 1,
                                                        );
                                                  },
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                  iconSize: 24,
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                            TextButton.icon(
                                              onPressed: () async {
                                                final confirmar =
                                                    await CustomConfirmDialog.showDelete(
                                                      context,
                                                      itemName:
                                                          item.producto.nombre,
                                                      type:
                                                          'producto del carrito',
                                                    );

                                                if (confirmar) {
                                                  await carritoService
                                                      .eliminarItem(
                                                        item.producto.id,
                                                      );
                                                  if (context.mounted) {
                                                    CustomOverlayNotification.showInfo(
                                                      context,
                                                      '${item.producto.nombre} eliminado del carrito',
                                                    );
                                                  }
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 14,
                                                color: Colors.red,
                                              ),
                                              label: const Text(
                                                'Eliminar',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 0,
                                                    ),
                                                minimumSize: const Size(0, 28),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
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
                    },
                  ),
                ),
                // Resumen del carrito
                Container(
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
                          /// HEADER (icono + título)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          letterSpacing: 0.1,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 3),

                          /// CONTENIDO PRINCIPAL
                          Row(
                            children: [
                              /// TOTAL
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 38,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '\$${carritoService.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              /// BOTÓN REALIZAR PEDIDO
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _realizarPedido(context),
                                    icon: const Icon(
                                      Icons.shopping_bag_rounded,
                                      size: 20,
                                    ),
                                    label: const Text('Realizar Pedido'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.blueAccent
                                          : const Color(0xFF0B0F18),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
}
