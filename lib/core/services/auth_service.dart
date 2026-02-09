import 'package:flutter/foundation.dart';
import '../../models/cliente.dart';

/// Servicio global para manejar la autenticación
/// Permite saber en cualquier parte de la app si el usuario está logueado
class AuthService extends ChangeNotifier {
  Cliente? _clienteActual;

  Cliente? get clienteActual => _clienteActual;
  bool get estaLogueado => _clienteActual != null;
  bool get esInstalador => _clienteActual?.esInstalador ?? false;

  void setCliente(Cliente? cliente) {
    _clienteActual = cliente;
    notifyListeners();
    if (kDebugMode) {
      if (cliente != null) {
        print(
          '✅ Usuario logueado: ${cliente.nombre} (${cliente.rol ?? "sin rol"})',
        );
      } else {
        print('❌ Usuario cerró sesión');
      }
    }
  }

  // Alias para compatibilidad
  void iniciarSesion(Cliente cliente) {
    setCliente(cliente);
  }

  void cerrarSesion() {
    _clienteActual = null;
    notifyListeners();
  }

  // 💰 Actualizar anticipos del cliente
  void actualizarClienteAnticipos(double nuevosAnticipos) {
    if (_clienteActual != null) {
      _clienteActual!.anticipos = nuevosAnticipos;
      notifyListeners();
      if (kDebugMode) {
        print(
          '💰 Anticipos actualizados: \$${nuevosAnticipos.toStringAsFixed(2)}',
        );
      }
    }
  }

  // 📊 Actualizar datos del cliente después de un pago
  void actualizarClienteDespuesPago({
    required double nuevosCupoUtilizado,
    required double nuevoSaldoDisponible,
    required double nuevosAnticipos,
  }) {
    if (_clienteActual != null) {
      _clienteActual = _clienteActual!.copyWith(
        cupoUtilizado: nuevosCupoUtilizado,
        saldoDisponible: nuevoSaldoDisponible,
        anticipos: nuevosAnticipos,
      );
      notifyListeners();
      if (kDebugMode) {
        print('📊 Datos del cliente actualizados después de pago');
        print(
          '   - Cupo Utilizado: \$${nuevosCupoUtilizado.toStringAsFixed(2)}',
        );
        print(
          '   - Saldo Disponible: \$${nuevoSaldoDisponible.toStringAsFixed(2)}',
        );
        print('   - Anticipos: \$${nuevosAnticipos.toStringAsFixed(2)}');
      }
    }
  }

  // 🔄 Actualizar cliente actual (recargar desde servidor si es necesario)
  Future<void> actualizarClienteActual() async {
    if (_clienteActual != null) {
      notifyListeners();
      if (kDebugMode) {
        print('🔄 Cliente actual actualizado');
      }
    }
  }
}
