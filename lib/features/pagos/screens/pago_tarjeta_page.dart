import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/services/mock_pagos_service.dart';
import '../../../core/logs/app_logger.dart';

/// 💳 PÁGINA DE PAGO CON TARJETA - Reusable Payment Page
///
/// Esta página reemplaza al modal `PagoTarjetaModal` y proporciona:
/// - WebView con Kushki JS SDK cargado dinámicamente
/// - Generación de token en ambiente SANDBOX
/// - Integración con backend Mock para procesar pagos
/// - Soporte para múltiples orígenes de pago (facturas, anticipos, etc)
///
/// Uso:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => PagoTarjetaPage(
///       monto: 100.0,
///       origen: 'detalle_factura',
///       onTokenGenerado: (token) {
///         // Procesar token aquí
///       },
///     ),
///   ),
/// );
/// ```
class PagoTarjetaPage extends StatefulWidget {
  final double monto;
  final String
  origen; // Identifier único: 'detalle_factura', 'abono_anticipos', etc
  final Function(String token) onTokenGenerado;
  final VoidCallback? onCancelado;

  const PagoTarjetaPage({
    super.key,
    required this.monto,
    required this.origen,
    required this.onTokenGenerado,
    this.onCancelado,
  });

  @override
  State<PagoTarjetaPage> createState() => _PagoTarjetaPageState();
}

class _PagoTarjetaPageState extends State<PagoTarjetaPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  late final bool _isWebViewSupported;

  // 🔑 KUSHKI SANDBOX - ID de comercio
  static const String _kushkiMerchantId = '20000000107542310000';

  @override
  void initState() {
    super.initState();
    _isWebViewSupported =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (_isWebViewSupported) {
      _initWebView();
    } else {
      _isLoading = false;
      AppLogger.logWarning(
        '⚠️ WebView no soportado en esta plataforma: $defaultTargetPlatform',
      );
    }
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            AppLogger.logInfo('✅ WebView Kushki cargado');
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.logError('❌ Error WebView: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'KushkiFlutter',
        onMessageReceived: (JavaScriptMessage message) {
          final token = message.message;
          AppLogger.logInfo('🔑 Token recibido desde Kushki JS: $token');
          _procesarTokenConBackend(token);
        },
      )
      ..addJavaScriptChannel(
        'FlutterCancel',
        onMessageReceived: (JavaScriptMessage message) {
          AppLogger.logInfo('❌ Usuario canceló el pago con tarjeta');
          if (widget.onCancelado != null) {
            widget.onCancelado!();
          }
          Navigator.pop(context);
        },
      )
      ..loadHtmlString(
        _getKushkiHtmlPage(),
        baseUrl: 'https://cdn.kushkipagos.com/',
      );
  }

  /// 🔄 Procesar token con el backend Mock
  Future<void> _procesarTokenConBackend(String token) async {
    AppLogger.logInfo(
      '💳 Procesando token en backend Mock | Origen: ${widget.origen}',
    );

    final pagosService = MockPagosService();

    final resultado = await pagosService.pagarConTarjeta(
      token: token,
      monto: widget.monto,
      facturaId: 0,
    );

    if (!mounted) return;

    if (resultado.exito) {
      AppLogger.logInfo('✅ Backend aprobó el pago');
      widget.onTokenGenerado(token);
      Navigator.pop(context);
    } else {
      AppLogger.logError('❌ Backend rechazó el pago: ${resultado.mensaje}');
      _mostrarAlertaError(resultado.mensaje, token);
    }
  }

  /// 🎨 Mostrar alerta de error sin cerrar la página
  void _mostrarAlertaError(String mensaje, String token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            // Determinar icono y color según el tipo de error
            IconData iconoError = Icons.error_outline;
            Color colorFondo = const Color.fromARGB(255, 0, 0, 0);

            if (mensaje.contains('información de la tarjeta')) {
              iconoError = Icons.credit_card_off;
              colorFondo = const Color.fromARGB(255, 0, 0, 0);
            } else if (mensaje.contains('intenta otro método')) {
              iconoError = Icons.account_balance_wallet;
              colorFondo = const Color.fromARGB(255, 0, 0, 0);
            } else if (mensaje.contains('seguridad')) {
              iconoError = Icons.security;
              colorFondo = const Color.fromARGB(255, 0, 0, 0);
            } else if (mensaje.contains('Error temporal')) {
              iconoError = Icons.cloud_off;
              colorFondo = const Color.fromARGB(255, 0, 0, 0);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colorFondo,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(iconoError, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Transacción No Aprobada',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B0F18),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    });
  }

  String _getKushkiHtmlPage() {
    return '''<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Simulador de Pasarela</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            border-bottom: 1px solid #eee;
            padding-bottom: 16px;
        }
        .header h1 {
            font-size: 20px;
            font-weight: bold;
        }
        .monto-box {
            background: #f0f8ff;
            border: 1px solid #b3e5fc;
            border-radius: 8px;
            padding: 12px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .monto-label {
            font-size: 14px;
            color: #666;
        }
        .monto-valor {
            font-size: 20px;
            font-weight: bold;
            color: #00a86b;
        }
        .sandbox-badge {
            background: #ffe6f0;
            border: 1px solid #ff4081;
            border-radius: 4px;
            padding: 8px;
            margin-bottom: 16px;
            font-size: 12px;
            color: #c2185b;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .sandbox-badge::before {
            content: "🧪";
        }
        .form-group {
            margin-bottom: 16px;
        }
        label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 6px;
            color: #333;
        }
        .card-number,
        .cardholder-name,
        .card-expiry,
        .card-cvv {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            font-family: monospace;
            background: #fafafa;
        }
        .card-number:focus,
        .cardholder-name:focus,
        .card-expiry:focus,
        .card-cvv:focus {
            outline: none;
            border-color: #00a86b;
            background: white;
        }
        .row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }
        .test-cards {
            background: #e3f2fd;
            border: 1px solid #90caf9;
            border-radius: 6px;
            padding: 12px;
            margin-bottom: 20px;
            font-size: 12px;
            color: #1565c0;
        }
        .test-cards strong {
            display: block;
            margin-bottom: 4px;
        }
        .test-cards code {
            background: rgba(255,255,255,0.5);
            padding: 2px 4px;
            border-radius: 2px;
            font-family: monospace;
        }
        .buttons {
            display: flex;
            gap: 12px;
            margin-top: 24px;
        }
        button {
            flex: 1;
            padding: 12px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }
        .btn-cancel {
            background: #f0f0f0;
            color: #333;
        }
        .btn-cancel:hover {
            background: #e0e0e0;
        }
        .btn-pay {
            background: #00a86b;
            color: white;
            flex: 1.5;
        }
        .btn-pay:hover {
            background: #00884d;
        }
        .btn-pay:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        .error {
            background: #ffebee;
            border: 1px solid #ef5350;
            border-radius: 6px;
            padding: 12px;
            margin-bottom: 16px;
            color: #c62828;
            font-size: 12px;
            display: none;
        }
        .error.show {
            display: block;
        }
        .loading {
            text-align: center;
            color: #666;
            font-size: 14px;
            display: none;
        }
        .loading.show {
            display: block;
        }
        .alert-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.5);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
        }
        .alert-overlay.show {
            display: flex;
        }
        .alert-box {
            background: white;
            border-radius: 16px;
            padding: 32px 24px;
            max-width: 400px;
            width: 90%;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
        }
        .alert-icon {
            width: 64px;
            height: 64px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 16px;
            font-size: 32px;
          color: #111;
          background: transparent;
        }
        .alert-icon svg {
          width: 32px;
          height: 32px;
          display: block;
        }
        .alert-icon.error {
          background: transparent;
        }
        .alert-icon.validation {
          background: transparent;
        }
        .alert-icon.funds {
          background: transparent;
        }
        .alert-icon.security {
          background: transparent;
        }
        .alert-icon.technical {
          background: transparent;
        }
        .alert-title {
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 8px;
            color: #0B0F18;
        }
        .alert-message {
            font-size: 14px;
            color: #666;
            margin-bottom: 24px;
            line-height: 1.4;
        }
        .btn-reintentar {
            width: 100%;
            padding: 12px;
            border: none;
            border-radius: 8px;
            background: #0B0F18;
            color: white;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.2s;
        }
        .btn-reintentar:hover {
            background: #1a1f2e;
            opacity: 0.9;
        }
    <\/style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Pago con Tarjeta</h1>
        </div>

        <div class="monto-box">
            <span class="monto-label">Monto a pagar:</span>
            <span class="monto-valor">\$${widget.monto.toStringAsFixed(2)}<\/span>
        </div>

        <div class="sandbox-badge">
            MODO SIMULACIÓN - Sin conexión a pasarela real
        </div>

        <div class="error" id="errorMsg"><\/div>
        <div class="loading" id="loadingMsg">Procesando...<\/div>

        <div class="alert-overlay" id="alertOverlay">
            <div class="alert-box">
                <div class="alert-icon" id="alertIcon"><\/div>
                <div class="alert-title" id="alertTitle">Transacción No Aprobada<\/div>
                <div class="alert-message" id="alertMessage"><\/div>
                <button class="btn-reintentar" id="btnReintentar">Vuelva a intentarlo<\/button>
            </div>
        </div>

        <form id="paymentForm">
            <div class="form-group">
                <label>Número de tarjeta</label>
                <input type="text" id="cardNumber" class="card-number" 
                       placeholder="4242 4242 4242 4242" maxlength="19">
            </div>

            <div class="form-group">
                <label>Nombre en la tarjeta</label>
                <input type="text" id="cardholderName" class="cardholder-name" 
                       placeholder="JUAN PEREZ" autocomplete="off">
            </div>

            <div class="row">
                <div class="form-group">
                    <label>MM/YY</label>
                    <input type="text" id="cardExpiry" class="card-expiry" 
                           placeholder="12/25" maxlength="5">
                </div>
                <div class="form-group">
                    <label>CVV</label>
                    <input type="text" id="cardCvv" class="card-cvv" 
                           placeholder="123" maxlength="4" inputmode="numeric">
                </div>
            </div>

            <div class="buttons">
                <button type="button" class="btn-cancel" onclick="cancelPayment()">Cancelar</button>
                <button type="submit" class="btn-pay" id="submitBtn">Pagar con Kushki</button>
            </div>
        </form>
    </div>

    <script>
        // ========================================
        // 🎭 SIMULADOR DE PASARELA DE PAGOS
        // Sin conexión real a Kushki/Datafast
        // ========================================
        
        console.log('🎭 Iniciando simulador de pasarela mock');
        
        const cardNumberInput = document.getElementById('cardNumber');
        const cardExpiryInput = document.getElementById('cardExpiry');
        const form = document.getElementById('paymentForm');
        const errorMsg = document.getElementById('errorMsg');
        const loadingMsg = document.getElementById('loadingMsg');
        const submitBtn = document.getElementById('submitBtn');
        const alertOverlay = document.getElementById('alertOverlay');
        const alertIcon = document.getElementById('alertIcon');
        const alertTitle = document.getElementById('alertTitle');
        const alertMessage = document.getElementById('alertMessage');
        const btnReintentar = document.getElementById('btnReintentar');
        
        // 🎯 Configuración de escenarios de prueba
        const PAYMENT_SCENARIOS = {
            '4242424242424242': {
                type: 'approved',
                token: 'mock_token_approved_',
                message: '¡Pago procesado con éxito!'
            },
            '4000000000000002': {
                type: 'validation_error',
                token: 'mock_token_validation_',
                message: 'La información de la tarjeta es incorrecta'
            },
            '4000000000009995': {
                type: 'insufficient_funds',
                token: 'mock_token_funds_',
                message: 'No se pudo completar la transacción, intenta otro método de pago'
            },
            '4000000000000069': {
                type: 'security_block',
                token: 'mock_token_blocked_',
                message: 'Por motivos de seguridad, esta transacción no puede ser procesada'
            },
            '4000000000000127': {
                type: 'technical_error',
                token: 'mock_token_error_',
                message: 'Error temporal al procesar el pago, intenta más tarde'
            }
        };
        
        function cancelPayment() {
            if (typeof FlutterCancel !== 'undefined') {
                FlutterCancel.postMessage('cancel');
            }
        }

        // 🎨 Función para mostrar alertas de error
        function showAlertError(message, errorType) {
            // Configurar icono y clase según tipo de error
          let iconoHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><line x1="8" y1="8" x2="16" y2="16" stroke="currentColor" stroke-width="2"/><line x1="16" y1="8" x2="8" y2="16" stroke="currentColor" stroke-width="2"/></svg>';
            let iconoClase = 'error';
            
            if (errorType === 'validation_error') {
            iconoHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="6" width="18" height="12" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="2"/><line x1="3" y1="10" x2="21" y2="10" stroke="currentColor" stroke-width="2"/></svg>';
                iconoClase = 'validation';
                alertTitle.textContent = 'Datos Inválidos';
            } else if (errorType === 'insufficient_funds') {
            iconoHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2"/><line x1="12" y1="7" x2="12" y2="17" stroke="currentColor" stroke-width="2"/><path d="M9 9.5c0-1 1.3-1.5 3-1.5s3 .5 3 1.5-1.3 1.5-3 1.5-3 .5-3 1.5 1.3 1.5 3 1.5 3-.5 3-1.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
                iconoClase = 'funds';
                alertTitle.textContent = 'Fondos Insuficientes';
            } else if (errorType === 'security_block') {
            iconoHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="9" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="2"/></svg>';
                iconoClase = 'security';
                alertTitle.textContent = 'Transacción Bloqueada';
            } else if (errorType === 'technical_error') {
            iconoHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3L2.5 20h19L12 3z" fill="none" stroke="currentColor" stroke-width="2"/><line x1="12" y1="9" x2="12" y2="14" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="17" r="1" fill="currentColor"/></svg>';
                iconoClase = 'technical';
                alertTitle.textContent = 'Error Temporal';
            } else {
                alertTitle.textContent = 'Transacción No Aprobada';
            }
            
            // Actualizar contenido de la alerta
          alertIcon.innerHTML = iconoHTML;
            alertIcon.className = 'alert-icon ' + iconoClase;
            alertMessage.textContent = message;
            
            // Mostrar overlay
            alertOverlay.classList.add('show');
            
            // Listener para reintentar
            btnReintentar.onclick = () => {
                alertOverlay.classList.remove('show');
                // Limpiar formulario y enfocarse en el campo de tarjeta
                cardNumberInput.focus();
            };
        }

        // Formateo de número de tarjeta
        cardNumberInput.addEventListener('input', (e) => {
            let value = e.target.value.replace(/\\s/g, '');
            if (value.length <= 16) {
                value = value.replace(/(\\d{4})/g, '\$1 ').trim();
                e.target.value = value;
            }
        });

        // Formateo de fecha de expiración
        cardExpiryInput.addEventListener('input', (e) => {
            let value = e.target.value;
            if (value.length === 2 && !value.includes('/')) {
                e.target.value = value + '/';
            }
        });

        // 🎭 Simulación del flujo de pago
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const cardNumber = cardNumberInput.value.replace(/\\s/g, '');
            const cardholderName = document.getElementById('cardholderName').value;
            const cardExpiry = cardExpiryInput.value;
            const cardCvv = document.getElementById('cardCvv').value;

            // Validaciones básicas de formulario
            if (!cardNumber || !cardholderName || !cardExpiry || !cardCvv) {
                showError('Completa todos los campos');
                return;
            }

            if (cardNumber.length < 13 || cardNumber.length > 19) {
                showError('Número de tarjeta inválido (debe tener entre 13 y 19 dígitos)');
                return;
            }

            if (cardExpiry.split('/').length !== 2) {
                showError('Formato de expiración inválido (MM/YY)');
                return;
            }

            if (cardCvv.length < 3) {
                showError('CVV inválido');
                return;
            }

            try {
                showLoading(true);
                submitBtn.disabled = true;
                
                console.log('🎭 Procesando pago simulado...');
                console.log('💳 Tarjeta:', cardNumber.substring(0, 6) + '******' + cardNumber.substring(cardNumber.length - 4));
                
                // Simular latencia de red (500-1500ms)
                const delay = Math.random() * 1000 + 500;
                await new Promise(resolve => setTimeout(resolve, delay));
                
                // 🎯 Determinar escenario basado en número de tarjeta
                const scenario = PAYMENT_SCENARIOS[cardNumber];
                
                if (!scenario) {
                    // Tarjeta no reconocida - tratar como error de validación
                    console.log('⚠️ Tarjeta no reconocida, usando escenario de validación');
                    showLoading(false);
                    submitBtn.disabled = false;
                    showAlertError('La información de la tarjeta es incorrecta', 'validation_error');
                    return;
                }
                
                console.log('🎭 Escenario detectado:', scenario.type);
                
                // Generar token mock único
                const timestamp = Date.now();
                const randomSuffix = Math.random().toString(36).substring(2, 8);
                const mockToken = scenario.token + timestamp + '_' + randomSuffix;
                
                console.log('🔑 Token generado:', mockToken);
                
                // ✅ Escenario APROBADO - enviar token a Flutter
                if (scenario.type === 'approved') {
                    showLoading(false);
                    console.log('✅ Pago aprobado - enviando token a Flutter');
                    if (typeof KushkiFlutter !== 'undefined') {
                        KushkiFlutter.postMessage(mockToken);
                    }
                    return;
                }
                
                // ❌ Otros escenarios - mostrar alerta y mantener en la página
                showLoading(false);
                submitBtn.disabled = false;
                
                // Mostrar alerta con overlay
                showAlertError(scenario.message, scenario.type);
                console.log('❌ Transacción rechazada:', scenario.type);
                
            } catch (err) {
                showLoading(false);
                submitBtn.disabled = false;
                showAlertError('Error inesperado: ' + err.message, 'technical_error');
                console.error('❌ Error en simulación:', err);
            }
        });

        function showError(msg) {
            errorMsg.textContent = msg;
            errorMsg.classList.add('show');
            setTimeout(() => {
                errorMsg.classList.remove('show');
            }, 5000);
        }

        function showLoading(show) {
            if (show) {
                loadingMsg.classList.add('show');
            } else {
                loadingMsg.classList.remove('show');
            }
        }
    <\/script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWebViewSupported) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pago con Tarjeta'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Pago con tarjeta no disponible en Windows',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Este flujo usa WebView, que no está soportado en esta plataforma.\nUsa Android o iOS para probar Kushki Sandbox.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago con Tarjeta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: WebViewWidget(controller: _webViewController),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
