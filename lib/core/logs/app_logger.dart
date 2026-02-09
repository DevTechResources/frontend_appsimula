import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Logger profesional para registrar eventos y errores en archivo
///
/// Uso:
/// ```
/// AppLogger.logInfo('Iniciando proceso de pago');
/// AppLogger.logError('Error al obtener PagosService', error, stackTrace);
/// ```
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  static File? _logFile;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  /// Inicializa el logger (debe llamarse en el main de la app)
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_logs.txt');

      // Crear archivo si no existe
      if (!_logFile!.existsSync()) {
        _logFile!.createSync(recursive: true);
      }

      // Log de inicialización
      await _writeLog('INIT', 'Logger inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando logger: $e');
    }
  }

  /// Registra un mensaje de información
  static void logInfo(String message) {
    _logWithType('INFO', message, null, null);
  }

  /// Registra un error con opción de incluir StackTrace
  static void logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final errorDetails = _formatError(error, stackTrace);
    _logWithType('ERROR', message, error, stackTrace);
    if (errorDetails.isNotEmpty) {
      _log(errorDetails);
    }
  }

  /// Registra un evento de advertencia
  static void logWarning(String message) {
    _logWithType('WARNING', message, null, null);
  }

  /// Registra un evento de depuración
  static void logDebug(String message) {
    _logWithType('DEBUG', message, null, null);
  }

  // ============ Métodos privados ============

  /// Formatea el log con tipo, fecha y mensaje
  static void _logWithType(
    String type,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final formattedLog =
        '[${_dateFormat.format(DateTime.now())}] [$type] $message';

    // Imprimir en consola con emojis para mejor visualización
    final emoji = _getEmoji(type);
    print('$emoji $formattedLog');

    // Escribir en archivo
    _writeLog(type, message, error, stackTrace);
  }

  /// Escribe el log en el archivo
  static Future<void> _writeLog(
    String type,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) async {
    if (_logFile == null) {
      print('⚠️  LogFile no inicializado');
      return;
    }

    try {
      final timestamp = _dateFormat.format(DateTime.now());
      final logEntry = '[$timestamp] [$type] $message';

      // Agregar error y stacktrace si existen
      final buffer = StringBuffer(logEntry);

      if (error != null) {
        buffer.writeln('\n  Error: $error');
      }

      if (stackTrace != null) {
        buffer.writeln('  StackTrace: $stackTrace');
      }

      buffer.writeln(); // Línea en blanco para separación

      // Agregar al final del archivo
      await _logFile!.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      print('❌ Error escribiendo en log file: $e');
    }
  }

  /// Escribe un texto sin estructura de log
  static Future<void> _log(String text) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString('$text\n', mode: FileMode.append);
    } catch (e) {
      print('❌ Error escribiendo en log file: $e');
    }
  }

  /// Formatea el error y stacktrace de forma legible
  static String _formatError(Object? error, StackTrace? stackTrace) {
    if (error == null && stackTrace == null) return '';

    final buffer = StringBuffer();

    if (error != null) {
      buffer.writeln('  Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('  StackTrace:');
      final lines = stackTrace.toString().split('\n');
      for (final line in lines.take(10)) {
        // Limitar a 10 primeras líneas
        if (line.trim().isNotEmpty) {
          buffer.writeln('    $line');
        }
      }
      if (lines.length > 10) {
        buffer.writeln('    ... (${lines.length - 10} más líneas)');
      }
    }

    return buffer.toString();
  }

  /// Retorna el emoji correspondiente al tipo de log
  static String _getEmoji(String type) {
    switch (type) {
      case 'INFO':
        return 'ℹ️';
      case 'ERROR':
        return '❌';
      case 'WARNING':
        return '⚠️';
      case 'DEBUG':
        return '🐛';
      case 'INIT':
        return '🚀';
      default:
        return '📝';
    }
  }

  /// Obtiene la ruta del archivo de logs
  static Future<String?> getLogFilePath() async {
    if (_logFile != null) {
      return _logFile!.path;
    }
    return null;
  }

  /// Limpia el archivo de logs
  static Future<void> clearLogs() async {
    if (_logFile != null && _logFile!.existsSync()) {
      try {
        await _logFile!.writeAsString('');
        logInfo('Archivo de logs borrado');
      } catch (e) {
        logError('Error borrando logs', e);
      }
    }
  }

  /// Lee y retorna todo el contenido del archivo de logs
  static Future<String?> readLogs() async {
    if (_logFile != null && _logFile!.existsSync()) {
      try {
        return await _logFile!.readAsString();
      } catch (e) {
        logError('Error leyendo logs', e);
        return null;
      }
    }
    return null;
  }
}
