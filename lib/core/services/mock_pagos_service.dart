import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/resultado_pago.dart';

class MockPagosService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.50.252:3000/api',
  );

  /// Procesar pago con tarjeta - Simula tokenización Kushki
  ///
  /// Parámetros:
  /// - token: Token generado por el simulador de pasarela
  /// - monto: Monto a pagar (> 0)
  /// - facturaId: ID de la factura (> 0)
  ///
  /// Retorna: ResultadoPago según el escenario codificado en el token
  Future<ResultadoPago> pagarConTarjeta({
    required String token,
    required double monto,
    required int facturaId,
  }) async {
    try {
      print('💳 [MockPagosService] Procesando pago simulado');
      print('   Token: ${token.substring(0, 20)}...');
      print('   Monto: \$$monto | Factura ID: $facturaId');

      // 🎭 Simular latencia de red (300-800ms)
      await Future.delayed(
        Duration(milliseconds: 300 + (token.hashCode % 500)),
      );

      // 🎯 Detectar escenario basado en el prefijo del token
      if (token.startsWith('mock_token_approved_')) {
        print('✅ Escenario: APROBADO');
        return ResultadoPago(
          exito: true,
          mensaje: '¡Pago procesado con éxito!',
        );
      } else if (token.startsWith('mock_token_validation_')) {
        print('❌ Escenario: ERROR DE VALIDACIÓN');
        return ResultadoPago(
          exito: false,
          mensaje: 'La información de la tarjeta es incorrecta',
        );
      } else if (token.startsWith('mock_token_funds_')) {
        print('❌ Escenario: FONDOS INSUFICIENTES');
        return ResultadoPago(
          exito: false,
          mensaje:
              'No se pudo completar la transacción, intenta otro método de pago',
        );
      } else if (token.startsWith('mock_token_blocked_')) {
        print('❌ Escenario: BLOQUEADA POR SEGURIDAD');
        return ResultadoPago(
          exito: false,
          mensaje:
              'Por motivos de seguridad, esta transacción no puede ser procesada',
        );
      } else if (token.startsWith('mock_token_error_')) {
        print('❌ Escenario: ERROR TÉCNICO');
        return ResultadoPago(
          exito: false,
          mensaje: 'Error temporal al procesar el pago, intenta más tarde',
        );
      }

      // 🔄 Si es un token real de Kushki (para cuando se implemente)
      // Este código quedará listo para la integración futura
      print('🔄 Token real detectado, enviando a backend...');

      final response = await http.post(
        Uri.parse('$baseUrl/pagos/tarjeta'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'monto': monto,
          'facturaId': facturaId,
        }),
      );

      print('   → Respuesta HTTP: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Pago exitoso: ${data['mensaje']}');
        return ResultadoPago(
          exito: data['exito'] ?? true,
          mensaje: data['mensaje'] ?? 'Pago procesado exitosamente',
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('❌ Error: ${data['mensaje']}');
        return ResultadoPago(
          exito: false,
          mensaje: data['mensaje'] ?? 'Token o datos inválidos',
        );
      } else {
        print('❌ Error HTTP ${response.statusCode}');
        return ResultadoPago(
          exito: false,
          mensaje: 'Error procesando pago. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Excepción en pagarConTarjeta: $e');
      return ResultadoPago(
        exito: false,
        mensaje: 'Error temporal al procesar el pago, intenta más tarde',
      );
    }
  }

  /// Procesar pago con otros métodos (compatibilidad)
  Future<ResultadoPago> pagarFactura({
    required int facturaId,
    required double monto,
    required String metodoPago,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    if (monto <= 0) {
      return ResultadoPago(exito: false, mensaje: 'Monto inválido');
    }

    return ResultadoPago(exito: true, mensaje: 'Pago simulado exitosamente');
  }
}
