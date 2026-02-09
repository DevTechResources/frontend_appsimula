import 'package:flutter/foundation.dart';
import '../../models/factura.dart';
import '../../models/pago.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../logs/app_logger.dart';
import 'ipagos_service.dart';
import '../models/resultado_pago.dart';

/// Resultado de una operación de pago
class ResultadoPago {
  final bool exito;
  final String mensaje;
  final Factura? facturaActualizada;
  final Pago? pago;
  final double? saldoPendiente;
  final double? excedente;
  final String? tipoOperacion; // PAGO_COMPLETO, ABONO_PARCIAL, EXCEDENTE

  ResultadoPago({
    required this.exito,
    required this.mensaje,
    this.facturaActualizada,
    this.pago,
    this.saldoPendiente,
    this.excedente,
    this.tipoOperacion,
  });
}

/// Servicio para gestionar pagos y abonos de facturas
///
/// Regla de negocio:
/// - El backend PROCESA la lógica de negocio
/// - El frontend SOLO envía datos mínimos: facturaId, monto, método
/// - El backend retorna el estado actualizado
class PagosService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService _authService;

  bool _isLoading = false;
  String? _errorMessage;
  ResultadoPago? _ultimoResultado;

  // Constructor con inyección de AuthService
  PagosService(this._authService);

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ResultadoPago? get ultimoResultado => _ultimoResultado;

  /// Procesar pago de una factura
  ///
  /// El backend automáticamente maneja la lógica:
  /// - Si monto < saldo: TODO va a anticipos (ABONO_PARCIAL)
  /// - Si monto = saldo: Factura completamente pagada (PAGO_COMPLETO)
  /// - Si monto > saldo: Factura pagada + diferencia a anticipos (EXCEDENTE)
  ///
  /// Parámetros:
  /// - facturaId: ID de la factura
  /// - monto: Monto a pagar (puede ser menor, igual o mayor al saldo)
  /// - metodoPago: Método de pago (transferencia, efectivo, tarjeta)
  ///
  /// Retorna: ResultadoPago con información del resultado
  Future<ResultadoPago> pagarFactura({
    required int facturaId,
    required double monto,
    required String metodoPago,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 🔑 OBTENER CLIENTE REAL DEL AUTHSERVICE (NO clienteId: 0)
      final clienteId = _authService.clienteActual?.id;

      if (clienteId == null || clienteId <= 0) {
        throw Exception('Cliente no válido para realizar el pago');
      }

      if (kDebugMode) {
        print('💳 Pagando factura #$facturaId');
        print('   Cliente: $clienteId');
        print('   Monto: \$$monto');
        print('   Método: $metodoPago');
      }

      // Validaciones básicas en cliente
      if (monto <= 0) {
        throw Exception('El monto debe ser mayor a 0');
      }

      // Generar número de pago único
      final numeroPago = 'PAG-${DateTime.now().millisecondsSinceEpoch}';

      // 📤 LOGGING: Antes de enviar
      AppLogger.logInfo(
        '📤 Enviando pago → clienteId=$clienteId | facturaId=$facturaId | monto=$monto',
      );

      // Enviar al backend con cliente REAL
      // El backend maneja automáticamente la lógica de split
      final pago = await _apiService.registrarPago(
        clienteId: clienteId,
        facturaId: facturaId,
        numeroPago: numeroPago,
        monto: monto,
        metodoPago: metodoPago,
        estadoPago: 'completado',
      );

      // Procesar respuesta - el backend retorna el tipo de operación
      _ultimoResultado = ResultadoPago(
        exito: true,
        mensaje: 'Pago registrado exitosamente',
        pago: pago,
        saldoPendiente: 0,
        tipoOperacion: 'PAGO_COMPLETO',
      );

      if (kDebugMode) {
        print('✅ Pago procesado exitosamente');
        print('   Número: ${pago.numeroPago}');
      }

      return _ultimoResultado!;
    } catch (e) {
      _errorMessage = e.toString();
      _ultimoResultado = ResultadoPago(
        exito: false,
        mensaje: 'Error al procesar pago: ${e.toString()}',
      );

      if (kDebugMode) {
        print('❌ Error al pagar: $e');
      }

      return _ultimoResultado!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Procesar abono parcial o pago flexible (con anticipos)
  ///
  /// Parámetros:
  /// - facturaId: ID de la factura
  /// - monto: Monto a abonar (puede ser menor, igual o mayor al saldo)
  /// - metodoPago: Método de pago
  ///
  /// Lógica del backend:
  /// - Si monto < saldo: TODO va a anticipos
  /// - Si monto = saldo: Factura completamente pagada
  /// - Si monto > saldo: Factura pagada + diferencia a anticipos
  Future<ResultadoPago> abonarFactura({
    required int facturaId,
    required double monto,
    required String metodoPago,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 🔑 OBTENER CLIENTE REAL DEL AUTHSERVICE (NO clienteId: 0)
      final clienteId = _authService.clienteActual?.id;

      if (clienteId == null || clienteId <= 0) {
        throw Exception('Cliente no válido para realizar el abono');
      }

      if (kDebugMode) {
        print('💵 Abonando factura #$facturaId');
        print('   Cliente: $clienteId');
        print('   Monto: \$$monto');
        print('   Método: $metodoPago');
      }

      if (monto <= 0) {
        throw Exception('El monto debe ser mayor a 0');
      }

      final numeroPago = 'ABONO-${DateTime.now().millisecondsSinceEpoch}';

      // 📤 LOGGING: Antes de enviar
      AppLogger.logInfo(
        '📤 Enviando abono → clienteId=$clienteId | facturaId=$facturaId | monto=$monto',
      );

      // El backend maneja la lógica de anticipos con cliente REAL
      final pago = await _apiService.registrarPago(
        clienteId: clienteId,
        facturaId: facturaId,
        numeroPago: numeroPago,
        monto: monto,
        metodoPago: metodoPago,
        estadoPago: 'completado',
      );

      _ultimoResultado = ResultadoPago(
        exito: true,
        mensaje: 'Abono registrado exitosamente',
        pago: pago,
        tipoOperacion: 'ABONO_PARCIAL',
      );

      if (kDebugMode) {
        print('✅ Abono procesado exitosamente');
      }

      return _ultimoResultado!;
    } catch (e) {
      _errorMessage = e.toString();
      _ultimoResultado = ResultadoPago(
        exito: false,
        mensaje: 'Error al procesar abono: ${e.toString()}',
      );

      if (kDebugMode) {
        print('❌ Error al abonar: $e');
      }

      return _ultimoResultado!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener historial de pagos de una factura
  Future<List<Pago>> obtenerPagosDeFactura(int facturaId) async {
    try {
      return await _apiService.getPagos(facturaId: facturaId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener pagos: $e');
      }
      return [];
    }
  }

  /// Limpiar mensaje de error
  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpiar último resultado
  void limpiarResultado() {
    _ultimoResultado = null;
    notifyListeners();
  }
}
