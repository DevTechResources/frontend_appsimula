import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/payment_receipt_widget.dart';
import '../core/services/payment_receipt_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentReceiptScreen({Key? key, required this.paymentData})
    : super(key: key);

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  late GlobalKey _receiptKey;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _receiptKey = GlobalKey();
  }

  Future<void> _captureAndShare() async {
    setState(() => _isProcessing = true);

    try {
      final imageBytes = await PaymentReceiptService.captureWidget(_receiptKey);

      if (imageBytes != null && mounted) {
        final facturaNum = widget.paymentData['numeroFactura'] ?? 'Comprobante';
        await PaymentReceiptService.shareImage(
          imageBytes,
          'Comprobante de Pago - $facturaNum',
          text: 'Comprobante de pago de Tech Resources generado en el app',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _captureAndSave() async {
    setState(() => _isProcessing = true);

    try {
      final imageBytes = await PaymentReceiptService.captureWidget(_receiptKey);

      if (imageBytes != null && mounted) {
        final saved = await PaymentReceiptService.saveToGallery(imageBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? '✅ Comprobante guardado correctamente'
                    : '❌ Error al guardar el comprobante',
              ),
              backgroundColor: saved ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobante de Pago'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // Contenido principal
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Comprobante
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PaymentReceiptWidget(
                    paymentData: widget.paymentData,
                    repaintKey: _receiptKey,
                  ),
                ),

                const SizedBox(height: 30),

                // Botones de acción
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Botón Compartir
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _captureAndShare,
                          icon: _isProcessing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.share, size: 20),
                          label: Text(
                            _isProcessing
                                ? 'Procesando...'
                                : 'Compartir Comprobante',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B0F18),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _captureAndSave,
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text(
                            'Guardar Comprobante',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0B0F18),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(
                              color: Color(0xFF0B0F18),
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón Volver
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Volver',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
