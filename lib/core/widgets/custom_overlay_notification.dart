import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme.dart';

/// Notificación que aparece adelante de TODO usando Overlay
/// Pequeña, en el centro superior, con animación
class CustomOverlayNotification {
  static OverlayEntry? _currentOverlay;
  static Timer? _timer;

  /// Mostrar notificación de éxito (verde con check)
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: AppColors.success,
    );
  }

  /// Mostrar notificación de error (rojo con X)
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.cancel,
      backgroundColor: AppColors.error,
    );
  }

  /// Mostrar notificación de advertencia (naranja con !)
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.warning,
      backgroundColor: AppColors.warning,
    );
  }

  /// Mostrar notificación de información (azul con i)
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info,
      backgroundColor: AppColors.info,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    // Remover overlay anterior si existe
    _currentOverlay?.remove();
    _timer?.cancel();

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
      ),
    );

    _currentOverlay = overlayEntry;
    overlay.insert(overlayEntry);

    // Auto-remover después de 2 segundos
    _timer = Timer(const Duration(seconds: 2), () {
      overlayEntry.remove();
      _currentOverlay = null;
    });
  }

  /// Ocultar notificación manualmente
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _timer?.cancel();
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;

  const _NotificationWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Iniciar animación de salida antes del auto-hide (2s total)
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
