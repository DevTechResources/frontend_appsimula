# AppLogger - Sistema Profesional de Logging

## Descripción
`AppLogger` es un sistema de logging profesional para Flutter que registra eventos y errores tanto en consola como en un archivo de texto dentro de la aplicación.

## Ubicación
- **Archivo principal**: `lib/core/logs/app_logger.dart`
- **Directorio de logs**: `Documents/app_logs.txt` (en el directorio de documentos de la aplicación)

## Características

✅ **Registro en archivo**: Los logs se guardan automáticamente en `app_logs.txt`  
✅ **Impresión en consola**: Cada log se imprime en consola con emojis para fácil identificación  
✅ **Sin dependencias externas**: Usa solo Dart y Flutter estándar + `path_provider`  
✅ **Rotación automática**: El archivo se crea automáticamente si no existe  
✅ **Stack traces**: Captura completa de excepciones con stack traces legibles  
✅ **Timestamps**: Cada log incluye fecha y hora precisas (milisegundos)

## Inicialización

En `main.dart`, antes de `runApp()`:

```dart
import 'core/logs/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Inicializar logger profesional
  await AppLogger.initialize();
  AppLogger.logInfo('=== Iniciando aplicación ===');

  runApp(...);
}
```

## Métodos Disponibles

### 1. **logInfo(String message)** - Registrar información
```dart
AppLogger.logInfo('Iniciando proceso de pago');
AppLogger.logInfo('Usuario logueado: ${user.email}');
```
**Emoji**: ℹ️  
**Nivel**: INFO

### 2. **logError(String message, [Object? error, StackTrace? stackTrace])** - Registrar errores
```dart
try {
  final result = await pagosService.pagarFactura(...);
} catch (e, stackTrace) {
  AppLogger.logError('Error al procesar pago', e, stackTrace);
}
```
**Emoji**: ❌  
**Nivel**: ERROR

### 3. **logWarning(String message)** - Registrar advertencias
```dart
AppLogger.logWarning('Widget no montado al finalizar operación');
```
**Emoji**: ⚠️  
**Nivel**: WARNING

### 4. **logDebug(String message)** - Registrar depuración
```dart
AppLogger.logDebug('PagosService obtenido correctamente');
```
**Emoji**: 🐛  
**Nivel**: DEBUG

## Métodos Utilitarios

### Obtener ruta del archivo
```dart
final path = await AppLogger.getLogFilePath();
print('Archivo de logs en: $path');
```

### Leer logs
```dart
final content = await AppLogger.readLogs();
print(content);
```

### Limpiar logs
```dart
await AppLogger.clearLogs();
```

## Formato de Logs

Cada entrada en el archivo tiene este formato:

```
[2026-01-28 14:35:22.145] [INFO] Iniciando proceso de pago

[2026-01-28 14:35:22.180] [ERROR] Error al obtener PagosService
  Error: Could not find the correct Provider<PagosService>
  StackTrace:
    #0 _procesarAbonoMultiple (package:app/features/facturas/screens/facturas_tab.dart:1190)
    #1 _showAbonoMultipleDialog (package:app/features/facturas/screens/facturas_tab.dart:1050)
    ... (más líneas)

[2026-01-28 14:35:23.200] [INFO] ✅ ÉXITO: Pago registrado con éxito en 2 factura(s)
```

## Integración en Flujo de Pagos

El logger ya está integrado en el flujo de pagos de `facturas_tab.dart`:

### En `_procesarPagoFactura()`
```dart
AppLogger.logInfo('Iniciando procesamiento de pago - Factura: ${factura.numeroFactura}');
AppLogger.logInfo('Monto: \$${monto.toStringAsFixed(2)} | Método: $metodoPago');

// Dentro del try
AppLogger.logDebug('✓ PagosService obtenido correctamente');

// Resultados
AppLogger.logInfo('✅ Pago procesado exitosamente - Actualizando facturas');

// Errores
AppLogger.logError('Error en pago: ${resultado.mensaje}');
AppLogger.logError('Excepción en _procesarPagoFactura', e, stackTrace);
```

### En `_procesarAbonoMultiple()`
```dart
AppLogger.logInfo('Iniciando abono múltiple - Facturas: ${facturas.length}');

// Obtención de servicios
AppLogger.logInfo('✓ PagosService obtenido correctamente');

// Procesamiento
AppLogger.logDebug('Procesando factura #${factura.numeroFactura}');

// Errores de Provider
AppLogger.logError('🚨 ERROR DE PROVIDER: El context no tiene acceso a los Providers necesarios');
```

## Casos de Uso

### 1. Depuración de Problemas de Provider
```dart
try {
  final pagosService = context.read<PagosService>();
} catch (e, stackTrace) {
  AppLogger.logError('Could not find PagosService', e, stackTrace);
  // El log ahora contiene toda la información para depuración
}
```

### 2. Auditoría de Transacciones
```dart
AppLogger.logInfo('Transacción iniciada - Factura: #${factura.id}, Monto: \$${monto}');
AppLogger.logInfo('Resultado: Exitoso - ID Transacción: ${resultado.id}');
```

### 3. Monitoreo de Ciclo de Vida
```dart
@override
void didPush() {
  AppLogger.logInfo('Pantalla de facturas abierta');
}

@override
void didPopNext() {
  AppLogger.logInfo('Volviendo a pantalla de facturas');
}
```

## Consultar Logs

Para revisar los logs en la aplicación:

1. **En el dispositivo/emulador**: Los logs se guardan en el directorio de documentos de la app
2. **Vía código**: Usa `AppLogger.readLogs()`
3. **Implementa una pantalla de depuración**: Crea una pantalla que muestre los logs

### Ejemplo de pantalla de logs (opcional)
```dart
class DebugLogsScreen extends StatefulWidget {
  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  late Future<String?> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = AppLogger.readLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📋 Logs')),
      body: FutureBuilder<String?>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(snapshot.data ?? 'Sin logs'),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

## Niveles de Log

| Nivel | Emoji | Uso |
|-------|-------|-----|
| INFO | ℹ️ | Información general sobre flujo de ejecución |
| ERROR | ❌ | Errores que requieren atención |
| WARNING | ⚠️ | Advertencias sobre situaciones inusuales |
| DEBUG | 🐛 | Información de depuración |
| INIT | 🚀 | Inicialización de servicios |

## Mejores Prácticas

✅ Usa `logInfo()` para eventos importantes  
✅ Usa `logError()` con el stackTrace para excepciones  
✅ Usa `logDebug()` para información detallada de depuración  
✅ Incluye contexto relevante en mensajes (IDs, montos, estados)  
✅ Revisa logs regularmente para identificar patrones de error  

❌ No registres información sensible (contraseñas, tokens)  
❌ No uses logs para depuración en bucles iterativos  
❌ No ignores los logs de error

## Limitaciones

- Los logs se guardan en texto plano (sin encriptación)
- El archivo crece indefinidamente (considerar limpiar periódicamente)
- No tiene rotación automática de archivos
- Solo mantiene logs locales (no se sincronizan con servidor)

## Futuras Mejoras

- [ ] Rotación automática de logs (máximo 1MB)
- [ ] Diferentes niveles de verbosidad
- [ ] Exportación de logs a email
- [ ] Compresión de logs antiguos
- [ ] Panel de control integrado en app

---

**Última actualización**: 28 de enero de 2026
