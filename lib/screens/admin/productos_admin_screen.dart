import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/producto.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/custom_overlay_notification.dart';
import '../../core/widgets/custom_confirm_dialog.dart';
import 'dart:convert';

class ProductosAdminScreen extends StatefulWidget {
  const ProductosAdminScreen({super.key});

  @override
  State<ProductosAdminScreen> createState() => _ProductosAdminScreenState();
}

class _ProductosAdminScreenState extends State<ProductosAdminScreen> {
  final ApiService _apiService = ApiService();
  List<Producto>? _productos;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final productos = await _apiService.obtenerProductos();
      setState(() {
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarProducto(int id, String nombre) async {
    final confirmar = await CustomConfirmDialog.showDelete(
      context,
      itemName: nombre,
      type: 'producto',
    );

    if (confirmar) {
      try {
        await _apiService.eliminarProducto(id);
        if (mounted) {
          CustomOverlayNotification.showSuccess(
            context,
            'Producto "$nombre" eliminado exitosamente',
          );
          _cargarProductos();
        }
      } catch (e) {
        if (mounted) {
          CustomOverlayNotification.showError(
            context,
            'Error al eliminar: ${e.toString().replaceAll("Exception:", "").trim()}',
          );
        }
      }
    }
  }

  void _mostrarFormulario({Producto? producto}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductoFormulario(
        producto: producto,
        onGuardar: () {
          Navigator.pop(context);
          _cargarProductos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarProductos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _productos?.length ?? 0,
              itemBuilder: (context, index) {
                final producto = _productos![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: producto.imagen != null
                        ? Image.network(
                            producto.imagen!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported),
                          )
                        : const Icon(Icons.image, size: 50),
                    title: Text(producto.nombre),
                    subtitle: Text(
                      '\$${producto.precio.toStringAsFixed(2)} - Stock: ${producto.stock}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _mostrarFormulario(producto: producto),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _eliminarProducto(producto.id, producto.nombre),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================================
// FORMULARIO DE PRODUCTO
// ============================================================================

class ProductoFormulario extends StatefulWidget {
  final Producto? producto;
  final VoidCallback onGuardar;

  const ProductoFormulario({super.key, this.producto, required this.onGuardar});

  @override
  State<ProductoFormulario> createState() => _ProductoFormularioState();
}

class _ProductoFormularioState extends State<ProductoFormulario> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _stockController = TextEditingController();
  final _imagenUrlController = TextEditingController();
  final _imagenBase64Controller = TextEditingController();

  bool _usarUrl = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.producto != null) {
      _nombreController.text = widget.producto!.nombre;
      _descripcionController.text = widget.producto!.descripcion ?? '';
      _precioController.text = widget.producto!.precio.toString();
      _stockController.text = widget.producto!.stock.toString();
      _imagenUrlController.text = widget.producto!.imagen ?? '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _imagenUrlController.dispose();
    _imagenBase64Controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'nombre': _nombreController.text,
        'descripcion': _descripcionController.text,
        'precio_publico': double.parse(_precioController.text),
        'stock': int.parse(_stockController.text),
        'categoria_id': 1, // TODO: Implementar selector de categoría
        'activo': true,
      };

      // Manejo de imagen
      if (_usarUrl && _imagenUrlController.text.isNotEmpty) {
        data['imagen_url'] = _imagenUrlController.text;
      } else if (!_usarUrl && _imagenBase64Controller.text.isNotEmpty) {
        // Validar que sea base64 válido
        try {
          base64.decode(_imagenBase64Controller.text);
          data['imagen_base64'] = _imagenBase64Controller.text;
        } catch (e) {
          throw Exception('Formato base64 inválido');
        }
      }

      final ApiService apiService = ApiService();

      if (widget.producto == null) {
        // Crear nuevo producto
        await apiService.crearProducto(data);
      } else {
        // Actualizar producto existente
        await apiService.actualizarProducto(widget.producto!.id, data);
      }

      if (mounted) {
        CustomOverlayNotification.showSuccess(
          context,
          widget.producto == null
              ? 'Producto creado exitosamente'
              : 'Producto actualizado exitosamente',
        );
        widget.onGuardar();
      }
    } catch (e) {
      if (mounted) {
        CustomOverlayNotification.showError(
          context,
          e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.producto == null ? 'Crear Producto' : 'Editar Producto',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Nombre
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Precio y Stock
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _precioController,
                      decoration: const InputDecoration(
                        labelText: 'Precio *',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Selector de tipo de imagen
              const Text(
                'Imagen del Producto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('URL'),
                      value: true,
                      groupValue: _usarUrl,
                      onChanged: (value) {
                        setState(() => _usarUrl = value!);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Base64'),
                      value: false,
                      groupValue: _usarUrl,
                      onChanged: (value) {
                        setState(() => _usarUrl = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Campo de imagen según selección
              if (_usarUrl)
                TextFormField(
                  controller: _imagenUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL de la imagen',
                    border: OutlineInputBorder(),
                    hintText: 'https://ejemplo.com/imagen.jpg',
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _imagenBase64Controller,
                      decoration: const InputDecoration(
                        labelText: 'Imagen en Base64',
                        border: OutlineInputBorder(),
                        hintText: 'Pega el código base64 aquí',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nota: Solo para imágenes pequeñas (< 100KB)',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
