import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../screens/payment_receipt_screen.dart';

class DatafastWebViewScreen extends StatefulWidget {
  final String url;
  final Map<String, dynamic> postData;
  final Map<String, dynamic>? displayData;

  const DatafastWebViewScreen({
    Key? key,
    required this.url,
    required this.postData,
    this.displayData,
  }) : super(key: key);

  @override
  State<DatafastWebViewScreen> createState() => _DatafastWebViewScreenState();
}

class _DatafastWebViewScreenState extends State<DatafastWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Error en WebView: ${error.description}');
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
        method: LoadRequestMethod.post,
        body: _buildPostBody(),
      );
  }

  /// Convierte el postData a formato application/x-www-form-urlencoded
  Uint8List _buildPostBody() {
    final params = widget.postData.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
        )
        .join('&');
    return Uint8List.fromList(params.codeUnits);
  }

  /// Verifica si el pago fue exitoso basándose en la URL
  void _checkPaymentStatus(String url) {
    // Ejemplo: Si la URL contiene "success" o "approved"
    // Ajusta esto según la respuesta real de Datafast
    if (url.contains('success') ||
        url.contains('approved') ||
        url.contains('completed')) {
      _handlePaymentSuccess();
    } else if (url.contains('error') ||
        url.contains('failed') ||
        url.contains('cancelled')) {
      _handlePaymentError();
    }
  }

  void _handlePaymentSuccess() {
    // Aquí podrías obtener más datos del pago si están en la URL
    // Por ejemplo, parseando query parameters

    if (!mounted) return;

    // Navegar directamente al comprobante
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            PaymentReceiptScreen(paymentData: _buildReceiptData()),
      ),
    );
  }

  Map<String, dynamic> _buildReceiptData() {
    final display = widget.displayData ?? {};
    final nowIso = DateTime.now().toIso8601String();

    return {
      'numeroFactura':
          display['numeroFactura'] ?? widget.postData['orderId'] ?? 'INV-0000',
      'numeroPago':
          display['numeroPago'] ??
          'PAG-${DateTime.now().millisecondsSinceEpoch}',
      'monto':
          display['monto'] ??
          double.tryParse(widget.postData['amount']?.toString() ?? '0') ??
          0.0,
      'metodoPago': display['metodoPago'] ?? 'datafast',
      'fechaPago': display['fechaPago'] ?? nowIso,
      'nombreProducto': display['nombreProducto'] ?? 'Pago de Factura',
      'rucCliente': display['rucCliente'] ?? 'N/A',
      'nombreCliente': display['nombreCliente'] ?? 'Cliente',
      'estado': display['estado'] ?? 'completado',
    };
  }

  void _handlePaymentError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ El pago no se completó'),
        backgroundColor: Colors.red,
      ),
    );

    // Volver a la pantalla anterior
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procesando Pago'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Confirmar si quiere cancelar
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancelar pago'),
                content: const Text(
                  '¿Estás seguro de que quieres cancelar el pago?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cerrar diálogo
                      Navigator.of(context).pop(); // Cerrar WebView
                    },
                    child: const Text('Sí, cancelar'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
