import '../models/resultado_pago.dart';

abstract class IPagosService {
  Future<ResultadoPago> pagarFactura({
    required int facturaId,
    required double monto,
    required String metodoPago,
  });
}
