import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../../models/cliente.dart';
import '../../models/producto.dart';
import '../../models/pedido.dart';
import '../../models/factura.dart';
import '../../models/pago.dart';
import '../../models/categoria.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.50.252:3000/api',
  );

  String? _token;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ====================
  // AUTENTICACIÓN
  // ====================

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clientes/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];

        // Guardar token en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        // El backend devuelve id_clientes en el objeto cliente
        await prefs.setInt('cliente_id', data['cliente']['id_clientes']);

        return data;
      } else {
        throw Exception('Error al iniciar sesión: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Iniciar pago con Datafast (obtiene datos del backend)
  Future<Map<String, dynamic>> iniciarPagoDatafast(int facturaId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pagos/datafast/iniciar'),
        headers: _getHeaders(),
        body: jsonEncode({'facturaId': facturaId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al iniciar pago: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('cliente_id');
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<int?> getClienteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('cliente_id');
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ====================
  // CATEGORÍAS
  // ====================

  Future<List<Categoria>> obtenerCategorias() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categorias'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // El backend devuelve {items: [...], total, page, perPage, totalPages}
        final List<dynamic> data = responseData['items'] ?? responseData;
        return data.map((json) => Categoria.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener categorías: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // CONFIGURACIÓN
  // ====================

  Future<double> obtenerIVA() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/configuracion/iva'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['iva_porcentaje'] ?? 15).toDouble();
      } else {
        return 15.0; // Valor por defecto
      }
    } catch (e) {
      return 15.0; // Valor por defecto en caso de error
    }
  }

  Future<void> actualizarIVA(double porcentaje) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/configuracion/iva'),
        headers: _getHeaders(),
        body: jsonEncode({'iva_porcentaje': porcentaje}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al actualizar IVA');
      }
    } catch (e) {
      throw Exception('Error al actualizar IVA: $e');
    }
  }

  // ====================
  // PRODUCTOS
  // ====================

  Future<List<Producto>> getProductos({
    String? q,
    int? categoriaId,
    double? precioMin,
    double? precioMax,
    int? perPage,
  }) async {
    try {
      // Construir query parameters
      final queryParams = <String, String>{};
      if (q != null && q.isNotEmpty) queryParams['q'] = q;
      if (categoriaId != null)
        queryParams['categoria_id'] = categoriaId.toString();
      if (precioMin != null) queryParams['precio_min'] = precioMin.toString();
      if (precioMax != null) queryParams['precio_max'] = precioMax.toString();
      // Solicitar muchos productos por defecto (1000) para evitar pérdida de datos
      queryParams['perPage'] = (perPage ?? 1000).toString();

      final uri = Uri.parse(
        '$baseUrl/productos',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // El backend devuelve {items: [...], total, page, perPage, totalPages}
        final List<dynamic> data = responseData['items'] ?? responseData;
        return data.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener productos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Alias para compatibilidad con pantallas existentes
  Future<List<Producto>> obtenerProductos() => getProductos();

  Future<Producto> getProducto(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/productos/$id'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return Producto.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al obtener producto: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ADMIN: Crear producto
  Future<Producto> crearProducto(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/productos'),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return Producto.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear producto: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ADMIN: Actualizar producto
  Future<Producto> actualizarProducto(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/productos/$id'),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return Producto.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al actualizar producto: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ADMIN: Eliminar producto
  Future<void> eliminarProducto(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/productos/$id'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar producto: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // PEDIDOS
  // ====================

  /// Crear pedido desde carrito (crea pedido + factura automáticamente)
  Future<Map<String, dynamic>> crearPedidoDesdeCarrito({
    required int clienteId,
    required List<Map<String, dynamic>> productos, // [{id: int, cantidad: int}]
    int? datosFacturacionId,
    int? direccionEnvioId,
  }) async {
    try {
      final body = {
        'cliente_id': clienteId,
        'productos': productos,
        if (datosFacturacionId != null)
          'datos_facturacion_id': datosFacturacionId,
        if (direccionEnvioId != null) 'direccion_envio_id': direccionEnvioId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/pedidos/desde-carrito'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Intentar extraer el mensaje de error del backend
        try {
          final errorBody = jsonDecode(response.body);
          final errorMessage =
              errorBody['error'] ??
              errorBody['message'] ??
              'Error al crear pedido';
          throw Exception(errorMessage);
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Error al crear pedido: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener información de crédito del cliente
  /// 💳 Se usa para actualizar UI después de una compra
  Future<Map<String, dynamic>> obtenerCreditoCliente(int clienteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/debug/credito/$clienteId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener crédito: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Pedido> crearPedido({
    required int clienteId,
    required String numeroPedido,
    required double subTotal,
    required double iva,
    required double descuento,
    required double total,
    required String tipoPago,
    required String estado,
    String? direccionEnvio,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: _getHeaders(),
        body: jsonEncode({
          'cliente_id': clienteId,
          'numero_pedido': numeroPedido,
          'sub_total': subTotal,
          'iva': iva,
          'descuento': descuento,
          'total': total,
          'tipo_pago': tipoPago,
          'estado': estado,
          'direccion_envio': direccionEnvio,
        }),
      );

      if (response.statusCode == 201) {
        return Pedido.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear pedido: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Pedido>> getPedidos({int? clienteId}) async {
    try {
      String url = '$baseUrl/pedidos';
      if (clienteId != null) {
        url += '?cliente_id=$clienteId';
      }

      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // El backend devuelve {page, perPage, total, data: [...]}
        final List<dynamic> data = responseData['data'] ?? responseData;
        return data.map((json) => Pedido.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener pedidos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // FACTURAS
  // ====================

  Future<Factura> crearFactura({
    required int pedidoId,
    required String tipoPago,
    double descuento = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/facturas'),
        headers: _getHeaders(),
        body: jsonEncode({
          'pedido_id': pedidoId,
          'tipo_pago': tipoPago,
          'descuento': descuento,
        }),
      );

      if (response.statusCode == 201) {
        return Factura.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear factura: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Factura>> getFacturas({int? clienteId}) async {
    try {
      String url = '$baseUrl/facturas';
      if (clienteId != null) {
        url += '?cliente_id=$clienteId';
      }

      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Factura.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener facturas: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Alias para compatibilidad con pantallas existentes
  Future<List<Factura>> obtenerFacturas({int? clienteId}) =>
      getFacturas(clienteId: clienteId);

  Future<String> descargarPdfFactura(int facturaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/facturas/$facturaId/pdf'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return 'PDF descargado exitosamente';
      } else {
        throw Exception('Error al descargar PDF: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // PAGOS (Con Notificaciones)
  // ====================

  Future<Pago> registrarPago({
    required int clienteId,
    required int facturaId,
    required String numeroPago,
    required double monto,
    required String metodoPago,
    String? referenciaPasarela,
    required String estadoPago,
  }) async {
    try {
      print(
        '📤 Enviando pago: clienteId=$clienteId, facturaId=$facturaId, monto=$monto',
      );

      // Construir el body sin campos null
      final Map<String, dynamic> body = {
        'cliente_id': clienteId,
        'factura_id': facturaId,
        'numero_pago': numeroPago,
        'monto': monto,
        'metodo_pago': metodoPago,
        'estado_pago': estadoPago,
      };

      // Solo agregar referencia_pasarela si no es null
      if (referenciaPasarela != null) {
        body['referencia_pasarela'] = referenciaPasarela;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/pagos'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print('✅ JSON decodificado correctamente');
        return Pago.fromJson(jsonData);
      } else {
        print('❌ Error del servidor: ${response.body}');
        throw Exception('Error al registrar pago: ${response.body}');
      }
    } catch (e) {
      print('❌ Excepción capturada: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Pago>> getPagos({int? facturaId}) async {
    try {
      String url = '$baseUrl/pagos';
      if (facturaId != null) {
        url += '?factura_id=$facturaId';
      }

      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Pago.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener pagos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // NOTIFICACIONES
  // ====================

  Future<void> registrarTokenFCM(String fcmToken, {String? dispositivo}) async {
    try {
      final clienteId = await getClienteId();
      if (clienteId == null) {
        throw Exception('No hay cliente autenticado');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/notificaciones/token'),
        headers: _getHeaders(),
        body: jsonEncode({
          'cliente_id': clienteId,
          'fcmToken': fcmToken,
          'dispositivo': dispositivo ?? 'Flutter App',
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Error al registrar token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> getEstadisticasNotificaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notificaciones/estadisticas'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener estadísticas: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ====================
  // MÉTODOS GENÉRICOS HTTP
  // ====================

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error en GET: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error en POST: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return jsonDecode(response.body);
      } else {
        throw Exception('Error en DELETE: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Método PATCH genérico
  Future<Map<String, dynamic>> patch(
    String endpoint, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: data != null ? jsonEncode(data) : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error en PATCH: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Método PUT genérico
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error en PUT: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
