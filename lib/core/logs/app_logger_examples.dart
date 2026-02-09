// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'app_logger.dart';

/// EJEMPLOS DE USO DE AppLogger EN DIFERENTES ESCENARIOS
///
/// Este archivo muestra cómo integrar el logger en diferentes partes
/// de tu aplicación Flutter.

class AppLoggerExamples {
  /// EJEMPLO 1: Logging en llamadas a API
  static Future<void> ejemplo1_ApiCall() async {
    try {
      AppLogger.logInfo('Iniciando llamada API para obtener facturas');

      // Simular llamada API
      final response = await Future.delayed(
        const Duration(seconds: 1),
        () => {'success': true, 'data': []},
      );

      AppLogger.logInfo('API respondió correctamente');
    } catch (e, stackTrace) {
      AppLogger.logError('Error en llamada API', e, stackTrace);
    }
  }

  /// EJEMPLO 2: Logging en operaciones de pago
  static Future<void> ejemplo2_PagoOperation() async {
    try {
      AppLogger.logInfo('📱 Iniciando operación de pago');
      AppLogger.logDebug('Monto: \$100.00 | Cliente: 12345');

      // Operación de pago
      final success = true;

      if (success) {
        AppLogger.logInfo('✅ Pago procesado exitosamente');
      } else {
        AppLogger.logError('Error: Pago rechazado por banco');
      }
    } catch (e) {
      AppLogger.logError('Excepción en operación de pago', e);
    }
  }

  /// EJEMPLO 3: Logging en cambios de estado
  static void ejemplo3_StateChanges() {
    AppLogger.logDebug('Estado actual: CARGANDO');
    AppLogger.logInfo('Usuario iniciando sesión');
    AppLogger.logDebug('Estado actual: AUTENTICADO');
  }

  /// EJEMPLO 4: Logging en manejo de errores
  static void ejemplo4_ErrorHandling() {
    try {
      // Simulamos un error
      throw Exception('No se pudo conectar a la base de datos');
    } catch (e, stackTrace) {
      AppLogger.logError('Falló la conexión a base de datos', e, stackTrace);
    }
  }

  /// EJEMPLO 5: Logging en navegación
  static void ejemplo5_Navigation() {
    AppLogger.logInfo('Navegando a pantalla de facturas');
    AppLogger.logDebug('Ruta: /facturas | Parámetros: {clienteId: 123}');
  }

  /// EJEMPLO 6: Logging en Provider
  static void ejemplo6_ProviderOperations() {
    try {
      AppLogger.logDebug('Obteniendo PagosService del contexto');
      // final pagosService = context.read<PagosService>();
      AppLogger.logInfo('✓ PagosService obtenido correctamente');
    } catch (e, stackTrace) {
      AppLogger.logError(
        'Error al obtener PagosService del contexto',
        e,
        stackTrace,
      );
    }
  }

  /// EJEMPLO 7: Logging en ciclo de vida de widgets
  static void ejemplo7_WidgetLifecycle() {
    AppLogger.logDebug('initState: Inicializando widget');
    AppLogger.logDebug('didChangeDependencies: Dependencias cambiadas');
    AppLogger.logDebug('build: Construyendo UI');
    AppLogger.logDebug('dispose: Limpiando recursos');
  }

  /// EJEMPLO 8: Logging en operaciones asincrónicas
  static Future<void> ejemplo8_AsyncOperations() async {
    AppLogger.logInfo('Iniciando operación asincrónica');

    try {
      AppLogger.logDebug('Paso 1: Validando datos');
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.logDebug('Paso 2: Procesando información');
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.logDebug('Paso 3: Guardando resultados');
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.logInfo('✅ Operación asincrónica completada');
    } catch (e, stackTrace) {
      AppLogger.logError('Operación asincrónica fallida', e, stackTrace);
    }
  }

  /// EJEMPLO 9: Logging de validaciones
  static bool ejemplo9_Validation(double monto, double saldoMinimo) {
    AppLogger.logDebug('Validando monto: \$$monto');

    if (monto <= 0) {
      AppLogger.logWarning('Monto inválido: debe ser mayor a 0');
      return false;
    }

    if (monto < saldoMinimo) {
      AppLogger.logWarning('Monto insuficiente: mínimo \$$saldoMinimo');
      return false;
    }

    AppLogger.logDebug('✓ Validación exitosa');
    return true;
  }

  /// EJEMPLO 10: Logging de multiples abonos
  static Future<void> ejemplo10_MultiplePayments() async {
    AppLogger.logInfo('Iniciando procesamiento de múltiples abonos');

    final facturas = ['FAC-001', 'FAC-002', 'FAC-003'];
    int abonosExitosos = 0;

    for (final factura in facturas) {
      try {
        AppLogger.logDebug('Procesando abono para $factura');

        // Simular operación
        await Future.delayed(const Duration(milliseconds: 300));

        AppLogger.logInfo('✓ Abono exitoso para $factura');
        abonosExitosos++;
      } catch (e) {
        AppLogger.logError('Error abonando $factura', e);
      }
    }

    AppLogger.logInfo(
      'Total de abonos exitosos: $abonosExitosos/${facturas.length}',
    );
  }

  /// EJEMPLO 11: Auditoría de transacciones
  static void ejemplo11_AuditTrail() {
    AppLogger.logInfo('🔒 AUDITORÍA - Transacción iniciada');
    AppLogger.logInfo(
      'Usuario: usuario@example.com | Hora: 2026-01-28 14:35:22',
    );
    AppLogger.logDebug('Acción: Pago de factura');
    AppLogger.logDebug('Monto: \$250.50 | Método: Transferencia');
    AppLogger.logInfo('Transacción completada exitosamente');
  }

  /// EJEMPLO 12: Logging de excepciones complejas
  static void ejemplo12_ComplexException() {
    try {
      throw FormatException('El formato de la respuesta es inválido');
    } catch (e, stackTrace) {
      AppLogger.logError(
        'Error procesando respuesta del servidor',
        e,
        stackTrace,
      );
    }
  }
}

/// PATRÓN DE USO EN UN SERVICIO
class EjemploServicio {
  Future<bool> procesarPago({
    required int facturaId,
    required double monto,
    required String metodo,
  }) async {
    try {
      AppLogger.logInfo('Servicio: Iniciando procesamiento de pago');
      AppLogger.logDebug(
        'Factura: $facturaId | Monto: \$$monto | Método: $metodo',
      );

      // Validar monto
      if (monto <= 0) {
        AppLogger.logError('Monto inválido: $monto');
        return false;
      }

      // Simular operación
      AppLogger.logDebug('Enviando solicitud a backend...');
      await Future.delayed(const Duration(seconds: 1));

      AppLogger.logInfo('✅ Pago procesado exitosamente');
      return true;
    } catch (e, stackTrace) {
      AppLogger.logError('Excepción en procesarPago', e, stackTrace);
      return false;
    }
  }
}

/// PATRÓN DE USO EN UN WIDGET
class EjemploWidget extends StatefulWidget {
  const EjemploWidget({super.key});

  @override
  State<EjemploWidget> createState() => _EjemploWidgetState();
}

class _EjemploWidgetState extends State<EjemploWidget> {
  @override
  void initState() {
    super.initState();
    AppLogger.logDebug('EjemploWidget: initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppLogger.logDebug('EjemploWidget: didChangeDependencies');
  }

  @override
  void dispose() {
    AppLogger.logDebug('EjemploWidget: dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.logDebug('EjemploWidget: build');

    return Scaffold(
      appBar: AppBar(title: const Text('Widget de ejemplo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            AppLogger.logInfo('Usuario presionó botón');
            // Operación...
          },
          child: const Text('Presionar'),
        ),
      ),
    );
  }
}

/// FUNCIONES HELPER RECOMENDADAS
class LoggerHelpers {
  /// Registra una operación larga
  static Future<T> logLongOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.logInfo('Iniciando: $operationName');

    try {
      final result = await operation();
      stopwatch.stop();
      AppLogger.logInfo(
        '✅ $operationName completado en ${stopwatch.elapsedMilliseconds}ms',
      );
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.logError(
        'Error en $operationName después de ${stopwatch.elapsedMilliseconds}ms',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Registra el inicio y fin de una operación sincrónica
  static T logSyncOperation<T>(String operationName, T Function() operation) {
    AppLogger.logDebug('Ejecutando: $operationName');

    try {
      final result = operation();
      AppLogger.logDebug('✓ $operationName completado');
      return result;
    } catch (e, stackTrace) {
      AppLogger.logError('Error en $operationName', e, stackTrace);
      rethrow;
    }
  }
}
