import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar los anticipos del cliente
/// Tamaño adaptativo al contenido, compacto y responsive
class AnticoposCard extends StatelessWidget {
  final double anticipos;
  final EdgeInsets? padding;
  final double? fontSize;
  final bool mostrarIcono;

  const AnticoposCard({
    super.key,
    required this.anticipos,
    this.padding,
    this.fontSize,
    this.mostrarIcono = true,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth( // 👈 ancho según contenido
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 130, // 👈 límite para que no sea rectangular largo
          minWidth: 90,  // 👈 tamaño compacto
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB81C),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center, // 👈 centra contenido
            children: [
              if (mostrarIcono)
                Row(
                  mainAxisSize: MainAxisSize.min, // 👈 evita estiramiento
                  children: [
                    const Icon(Icons.savings, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      'Abono',
                      style: TextStyle(
                        fontSize: fontSize ?? 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Abono',
                  style: TextStyle(
                    fontSize: fontSize ?? 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 4),
              FittedBox( // 👈 texto crece/disminuye según espacio
                fit: BoxFit.scaleDown,
                child: Text(
                  '\$${anticipos.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: (fontSize ?? 13) + 1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
