import 'package:flutter/material.dart';

/// Diálogo de confirmación personalizado
/// Muestra una pregunta con dos botones: Cancelar y Confirmar
class CustomConfirmDialog {
  /// Mostrar diálogo de confirmación
  /// Retorna true si el usuario confirma, false si cancela
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    Color confirmColor = const Color(0xFF4CAF50),
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConfirmDialogWidget(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Confirmación para eliminar algo
  static Future<bool> showDelete(
    BuildContext context, {
    required String itemName,
    String type = 'elemento',
  }) async {
    return await show(
      context,
      title: '¿Eliminar $type?',
      message:
          '¿Estás seguro de eliminar "$itemName"? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
      confirmColor: const Color(0xFFE53935),
      icon: Icons.delete_forever,
    );
  }

  /// Confirmación para realizar pago
  static Future<bool> showPayment(
    BuildContext context, {
    required String amount,
  }) async {
    return await show(
      context,
      title: '¿Confirmar pago?',
      message: '¿Estás seguro de realizar el pago de $amount?',
      confirmText: 'Realizar Pago',
      cancelText: 'Cancelar',
      confirmColor: const Color(0xFF2196F3),
      icon: Icons.payment,
    );
  }

  /// Confirmación genérica de acción
  static Future<bool> showAction(
    BuildContext context, {
    required String action,
    required String details,
  }) async {
    return await show(
      context,
      title: action,
      message: details,
      confirmText: 'Aceptar',
      cancelText: 'Cancelar',
      confirmColor: const Color(0xFFFF9800),
      icon: Icons.help_outline,
    );
  }
}

class _ConfirmDialogWidget extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData? icon;

  const _ConfirmDialogWidget({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      // 1. CORRECCIÓN: Fondo del diálogo según el tema
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: confirmColor),
              ),
              const SizedBox(height: 16),
            ],

            // Título
            Text(
              title,
              style: TextStyle(
                // <--- Sin 'const'
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Mensaje
            Text(
              message,
              style: TextStyle(
                // <--- Sin 'const'
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Botones
            Row(
              children: [
                // Botón Cancelar
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      // 2. CORRECCIÓN: Borde gris más claro en modo oscuro
                      side: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        // <--- Cambiado a dinámico
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        // 3. CORRECCIÓN: Texto legible en ambos modos
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Botón Confirmar
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
