import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/pagos_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../models/factura.dart';
import '../../../models/pago.dart';
import '../../facturas/screens/facturas_tab.dart';
import '../../pagos/screens/pago_tarjeta_page.dart';
import '../../facturas/screens/factura_detalle_screen.dart';
import '../../../screens/main_screen.dart';
import '../../../core/widgets/custom_snackbar.dart';

import 'historial_movimientos_screen.dart';

class CreditoTab extends StatefulWidget {
  const CreditoTab({super.key});

  @override
  State<CreditoTab> createState() => _CreditoTabState();
}

class _CreditoTabState extends State<CreditoTab>
    with RouteAware, WidgetsBindingObserver {
  int _vistaActual = 0;
  final TextEditingController _montoController = TextEditingController();
  final Map<int, bool> _facturasSeleccionadasParaPago = {};
  double _montoPreconfigurado = 0;
  bool _cargaFacturasInicialHecha = false;
  bool _cargaPagoFacturasIntentada = false;

  // 🏷️ Filtros para Pago de Facturas
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _textoBusqueda = '';
  double? _montoMinimo;

  @override
  void initState() {
    super.initState();
    // Escuchar estado de ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _montoController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Unsubscribe RouteObserver
    try {
      final route = ModalRoute.of(context);
      if (route != null) routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  // 🏷️ Limpiar filtros
  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _textoBusqueda = '';
      _montoMinimo = null;
    });
  }

  // 💰 Toggle para seleccionar/deseleccionar todas las facturas
  void _toggleSeleccionarTodo(List<Factura> facturasPendientes) {
    final facturasDisponibles = _aplicarFiltrosFacturas(facturasPendientes);

    final todasSeleccionadas = facturasDisponibles.every(
      (f) => _facturasSeleccionadasParaPago[f.id] == true,
    );

    setState(() {
      for (final factura in facturasDisponibles) {
        _facturasSeleccionadasParaPago[factura.id] = !todasSeleccionadas;
      }
    });
  }

  // 🏷️ Seleccionar rango de fechas
  Future<void> _seleccionarRangoFechasFacturas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fechaInicio != null && _fechaFin != null
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : null,
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
    }
  }

  // 🏷️ Aplicar filtros a las facturas
  List<Factura> _aplicarFiltrosFacturas(List<Factura> facturas) {
    return facturas.where((f) {
      // Filtro de fecha
      final coincideFecha =
          _fechaInicio == null ||
          _fechaFin == null ||
          (f.fechaEmision != null &&
              f.fechaEmision!.isAfter(_fechaInicio!) &&
              f.fechaEmision!.isBefore(
                _fechaFin!.add(const Duration(days: 1)),
              ));

      // Filtro de búsqueda (cliente o número de factura)
      final coincideTexto =
          _textoBusqueda.isEmpty ||
          f.numeroFactura.toString().contains(_textoBusqueda) ||
          (f.clienteId.toString().contains(_textoBusqueda));

      // Filtro de monto mínimo
      final coincideMonto = _montoMinimo == null || f.total >= _montoMinimo!;

      return coincideFecha && coincideTexto && coincideMonto;
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suscribir al RouteObserver para detectar cuando la pantalla vuelve a ser visible
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
    // Asegurar que esta pantalla cargue sus propios datos de facturas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final facturasService = Provider.of<FacturasService>(
          context,
          listen: false,
        );
        if (!_cargaFacturasInicialHecha &&
            authService.estaLogueado &&
            facturasService.facturas.isEmpty &&
            !facturasService.isLoading) {
          _cargaFacturasInicialHecha = true;
          facturasService.fetchFacturas(
            clienteId: authService.clienteActual?.id,
            esAdmin: authService.esInstalador,
          );
        }
      } catch (_) {}
    });
  }

  // RouteAware callbacks
  @override
  void didPush() {
    // pantalla fue empujada -> cargar datos
    if (mounted) {
      _refrescarTodosDatos();
      debugPrint(
        '🟢 [DIDPUSH-CREDITO] Pantalla de crédito mostrada, refrescando datos...',
      );
    }
  }

  @override
  void didPopNext() {
    // Volvió a esta pantalla desde otra encima -> refrescar
    if (mounted) {
      debugPrint(
        '🟡 [DIDPOPNEXT-CREDITO] Volviendo a pantalla de crédito, refrescando datos...',
      );
      _refrescarTodosDatos();
    }
  }

  // App lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // La app volvió a foreground -> refrescar
      debugPrint('🔵 [APP-RESUMED] App regresó a foreground, refrescando...');
      _refrescarTodosDatos();
    }
  }

  /// Refrescar todos los datos del crédito y facturas
  void _refrescarTodosDatos() {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );

    // No intentar cargar si no hay usuario logueado
    if (authService.clienteActual == null) return;

    debugPrint('📊 Refrescando: Estado de Crédito, Mis Facturas, Pagos...');

    // Cargar facturas (esto actualiza todas las vistas)
    facturasService.fetchFacturas(
      clienteId: authService.clienteActual?.id,
      esAdmin: authService.esInstalador,
    );

    // 🏷️ Actualizar información de cliente (crédito)
    authService.actualizarClienteActual();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final cliente = authService.clienteActual;

    if (!authService.estaLogueado) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Debes estar logueado para ver tu crédito'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  MainScreenState.cambiarPestanaGlobal(4);
                },
                icon: const Icon(Icons.login),
                label: const Text('Iniciar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0F18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_vistaActual == 2) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Facturas'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _vistaActual = 0;
              });
            },
          ),
        ),
        body: FacturasTab(),
      );
    }

    if (_vistaActual == 3) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Abono Múltiple'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _vistaActual = 0;
                _montoPreconfigurado = 0;
              });
            },
          ),
        ),
        body: FacturasTab(
          modoAbonoMultiple: true,
          montoPreconfigurado: _montoPreconfigurado,
        ),
      );
    }

    if (_vistaActual == 4) {
      return _buildPagoFacturas(context);
    }

    if (_vistaActual == 1) {
      return _buildEstadoCredito(context, cliente);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Pantalla demasiado pequeña',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _buildMenuPrincipal(context);
      },
    );
  }

  Widget _buildMenuPrincipal(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Gestión de Crédito',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona una opción para continuar',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              children: [
                _cardMenu(
                  icon: Icons.assessment,
                  titulo: 'Estado de crédito',
                  onTap: () {
                    setState(() {
                      _vistaActual = 1;
                    });
                  },
                ),
                _cardMenu(
                  icon: Icons.receipt_long,
                  titulo: 'Mis facturas',
                  onTap: () {
                    setState(() {
                      _vistaActual = 2;
                    });
                  },
                ),
                _cardMenu(
                  icon: Icons.payments_outlined,
                  titulo: 'Abono',
                  onTap: () {
                    setState(() {
                      _vistaActual = 3;
                    });
                  },
                ),
                _cardMenu(
                  icon: Icons.receipt_long_outlined,
                  titulo: 'Pago Facturas',
                  onTap: () {
                    setState(() {
                      _vistaActual = 4;
                    });
                  },
                ),
                _cardMenu(
                  icon: Icons.lock,
                  titulo: 'Términos y condiciones',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardMenu({
    required IconData icon,
    required String titulo,
    required VoidCallback onTap,
  }) {
    const textColor = Color(0xFF0B0F18);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: textColor),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoCredito(BuildContext context, dynamic cliente) {
    final cupoTotal = cliente?.cupoCredito ?? 0.0;
    final cupoUtilizado = cliente?.cupoUtilizado ?? 0.0;
    final saldoDisponible = cliente?.saldoDisponible ?? 0.0;
    final valorVencido = cliente?.valorVencido ?? 0.0;
    final diasPlazo = cliente?.diasPlazo ?? 0;

    if (kDebugMode) {
      print('📊 CREDITO TAB DEBUG:');
      print('   - Cupo Total: \$${cupoTotal.toStringAsFixed(2)}');
      print('   - Cupo Utilizado: \$${cupoUtilizado.toStringAsFixed(2)}');
      print('   - Saldo Disponible: \$${saldoDisponible.toStringAsFixed(2)}');
      print('   - Valor Vencido: \$${valorVencido.toStringAsFixed(2)}');
      print('   - Días Plazo: $diasPlazo');
    }

    // Obtener la factura próxima a vencer
    final facturasService = Provider.of<FacturasService>(context);
    // Asegurar carga independiente de facturas si aún no se cargaron
    if (!facturasService.isLoading && facturasService.facturas.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final authService = Provider.of<AuthService>(context, listen: false);
          if (authService.estaLogueado) {
            facturasService.fetchFacturas(
              clienteId: authService.clienteActual?.id,
              esAdmin: authService.esInstalador,
            );
          }
        } catch (_) {}
      });
    }
    final facturaProximaAVencer = _obtenerFacturaProximaAVencer(
      facturasService.facturas,
    );

    // Obtener el último pago
    final ultimoPago = _obtenerUltimoPago(facturasService.facturas);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Crédito'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _vistaActual = 0;
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gráfico circular con información consolidada
            CreditoCircularChart(
              cupoTotal: cupoTotal,
              cupoUtilizado: cupoUtilizado,
              saldoDisponible: saldoDisponible,
            ),
            // � Abono (texto plano sin icono)

            // Información de pagos
            Container(
              padding: const EdgeInsets.all(5),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de Pagos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Tarjeta de Próximo Pago
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Próximo Pago',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          if (facturasService.isLoading) ...[
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Cargando información de pagos...'),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (facturaProximaAVencer != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Días para vencer',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_calcularDiasParaVencimiento(facturaProximaAVencer.fechaVencimiento)} días',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Valor a Pagar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${facturaProximaAVencer.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Información de la factura próxima a vencer
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FacturaDetalleScreen(
                                      factura: facturaProximaAVencer,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    239,
                                    239,
                                    239,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      110,
                                      110,
                                      110,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Fac: ${facturaProximaAVencer.numeroFactura}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade200,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            facturaProximaAVencer.estado,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Creada: ${_formatearFecha(facturaProximaAVencer.fechaEmision ?? DateTime.now())}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vence: ${_formatearFecha(facturaProximaAVencer.fechaVencimiento ?? DateTime.now())}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'No hay facturas pendientes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          // Último movimiento (Pago)
                          Row(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 18,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HistorialMovimientosScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Historial de Movimientos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (facturasService.isLoading) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: const [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cargando último pago...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (ultimoPago != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Último Pago',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ultimoPago.numeroPago,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatearFecha(
                                                ultimoPago.fechaCreacion ??
                                                    DateTime.now(),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '\$${ultimoPago.monto.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              ultimoPago.estadoPago,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Obtener la factura próxima a vencer
  Factura? _obtenerFacturaProximaAVencer(List<Factura> facturas) {
    // Filtrar solo facturas con saldo pendiente
    final facturasPendientes = facturas
        .where((f) => f.saldoPendiente > 0 && f.estado == 'emitida')
        .toList();

    if (facturasPendientes.isEmpty) return null;

    // Ordenar por fecha de vencimiento (próximas a vencer primero)
    facturasPendientes.sort((a, b) {
      final fechaAVencimiento = a.fechaVencimiento ?? DateTime(2099);
      final fechaBVencimiento = b.fechaVencimiento ?? DateTime(2099);
      return fechaAVencimiento.compareTo(fechaBVencimiento);
    });

    return facturasPendientes.first;
  }

  /// Obtener el último pago realizado
  Pago? _obtenerUltimoPago(List<Factura> facturas) {
    // Si no hay facturas, retornar null
    if (facturas.isEmpty) return null;

    // Crear un pago simulado basado en la última factura pagada
    // Esto se puede mejorar cuando tengamos un endpoint específico para pagos
    final facturasPagadas = facturas
        .where((f) => f.estado.toLowerCase() == 'pagada')
        .toList();

    if (facturasPagadas.isEmpty) return null;

    // Ordenar por fecha de emisión descendente (más recientes primero)
    facturasPagadas.sort((a, b) {
      final fechaA = a.fechaEmision ?? DateTime(1980);
      final fechaB = b.fechaEmision ?? DateTime(1980);
      return fechaB.compareTo(fechaA);
    });

    // Obtener la última factura pagada
    final ultimaFacturaPagada = facturasPagadas.first;

    // Crear un objeto Pago simulado para mostrar
    return Pago(
      id: ultimaFacturaPagada.id,
      clienteId: ultimaFacturaPagada.clienteId,
      facturaId: ultimaFacturaPagada.id,
      numeroPago: 'PAG-FAC-${ultimaFacturaPagada.numeroFactura}',
      monto: ultimaFacturaPagada.total,
      metodoPago: ultimaFacturaPagada.tipoPago,
      estadoPago: 'completado',
      fechaCreacion: ultimaFacturaPagada.fechaEmision ?? DateTime.now(),
    );
  }

  /// Calcular días para vencimiento
  int _calcularDiasParaVencimiento(DateTime? fechaVencimiento) {
    if (fechaVencimiento == null) return 0;
    final ahora = DateTime.now();
    return fechaVencimiento.difference(ahora).inDays;
  }

  /// Formatear fecha
  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  Widget _buildPagoFacturas(BuildContext context) {
    final facturasService = Provider.of<FacturasService>(context);

    // Si el servicio está cargando y aún no hay facturas, mostrar indicador
    if (facturasService.isLoading && facturasService.facturas.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pago de Facturas'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _vistaActual = 0;
                _facturasSeleccionadasParaPago.clear();
                _montoController.clear();
              });
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Si no hay facturas y no está cargando, disparar la carga (una sola vez)
    if (!_cargaPagoFacturasIntentada &&
        !facturasService.isLoading &&
        facturasService.facturas.isEmpty) {
      _cargaPagoFacturasIntentada = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final authService = Provider.of<AuthService>(context, listen: false);
          if (authService.estaLogueado) {
            facturasService.fetchFacturas(
              clienteId: authService.clienteActual?.id,
              esAdmin: authService.esInstalador,
            );
          }
        } catch (_) {}
      });
    }

    final facturasPendientes = List<Factura>.from(
      facturasService.facturas
          .where((f) => f.saldoPendiente > 0 && f.estado == 'emitida')
          .toList(),
    );

    // Ordenar por fecha de emisión (más recientes primero), luego por fecha de vencimiento
    facturasPendientes.sort((a, b) {
      final fechaAEmision = a.fechaEmision ?? DateTime(1980);
      final fechaBEmision = b.fechaEmision ?? DateTime(1980);

      // Primero por fecha de emisión (descendente - más recientes primero)
      final comparacionEmision = fechaBEmision.compareTo(fechaAEmision);
      if (comparacionEmision != 0) return comparacionEmision;

      // Si tienen la misma fecha de emisión, ordenar por vencimiento
      return (a.fechaVencimiento ?? DateTime(2099)).compareTo(
        (b.fechaVencimiento) ?? DateTime(2099),
      );
    });

    double montoTotalSeleccionado = 0;
    int facturasTotalesSeleccionadas = 0;
    for (var factura in facturasPendientes) {
      if (_facturasSeleccionadasParaPago[factura.id] ?? false) {
        montoTotalSeleccionado += factura.total;
        facturasTotalesSeleccionadas++;
      }
    }

    final hayFiltros =
        _fechaInicio != null ||
        _textoBusqueda.isNotEmpty ||
        _montoMinimo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de Facturas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _vistaActual = 0;
              _facturasSeleccionadasParaPago.clear();
              _montoController.clear();
            });
          },
        ),
      ),
      body: facturasPendientes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay facturas pendientes',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // 🏷️ FILTROS FECHA  COMPACTOS Y RESPONSIVE
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _filtroFecha()),
                      const SizedBox(width: 6),
                      Expanded(child: _filtroBusqueda()),
                      const SizedBox(width: 6),
                      Expanded(child: _filtroMonto()),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () =>
                            _toggleSeleccionarTodo(facturasPendientes),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: hayFiltros ? _limpiarFiltros : null,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _aplicarFiltrosFacturas(
                      facturasPendientes,
                    ).length,
                    itemBuilder: (context, index) {
                      final facturasFiltradas = _aplicarFiltrosFacturas(
                        facturasPendientes,
                      );
                      final factura = facturasFiltradas[index];
                      final estaSeleccionada =
                          _facturasSeleccionadasParaPago[factura.id] ?? false;

                      final ahora = DateTime.now();
                      final diasParaVencimiento =
                          (factura.fechaVencimiento ?? DateTime(2099))
                              .difference(ahora)
                              .inDays;
                      final esVencida = diasParaVencimiento < 0;
                      final esProximaVencer =
                          diasParaVencimiento >= 0 && diasParaVencimiento <= 7;

                      Color colorVencimiento = Colors.green;
                      String textoVencimiento = 'Normal';
                      if (esVencida) {
                        colorVencimiento = Colors.red;
                        textoVencimiento =
                            'VENCIDA (${-diasParaVencimiento} días)';
                      } else if (esProximaVencer) {
                        colorVencimiento = Colors.orange;
                        textoVencimiento = 'Vence en $diasParaVencimiento días';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: estaSeleccionada
                            ? Colors.blue.shade50
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          side: estaSeleccionada
                              ? const BorderSide(
                                  color: Color(0xFF0B0F18),
                                  width: 2,
                                )
                              : BorderSide.none,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: estaSeleccionada,
                                    onChanged: (value) {
                                      setState(() {
                                        _facturasSeleccionadasParaPago[factura
                                                .id] =
                                            value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Factura #${factura.numeroFactura}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0B0F18),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Emitida: ${DateFormat('dd/MM/yyyy').format(factura.fechaEmision ?? DateTime.now())}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorVencimiento.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      textoVencimiento,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colorVencimiento,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Monto Total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${factura.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0B0F18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🏷️ Botón "Seleccionar Todo" para Pago de Facturas
                      if (facturasTotalesSeleccionadas > 0) ...[
                        const Text(
                          'Resumen de Pago',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B0F18),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Facturas Seleccionadas:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '$facturasTotalesSeleccionadas',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B0F18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Monto Total Seleccionado:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '\$${montoTotalSeleccionado.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Monto Total a Pagar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0B0F18),
                                    ),
                                  ),
                                  Text(
                                    '\$${montoTotalSeleccionado.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Ingrese el Monto',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B0F18),
                                ),
                              ),
                              const SizedBox(height: 3),
                              TextField(
                                controller: _montoController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  prefixText: '\$',
                                  prefixStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  suffixIcon: _montoController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _montoController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getTextoAbonoInfo(
                                  double.tryParse(_montoController.text) ?? 0,
                                  montoTotalSeleccionado,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _montoController.text.isEmpty
                              ? null
                              : () => _procesarPagoMultipleFacturas(
                                  facturasPendientes,
                                  double.tryParse(_montoController.text) ?? 0,
                                  context,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B0F18),
                            minimumSize: const Size(double.infinity, 26),
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Procesar Pago',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                      ] else
                        const Text(
                          'Selecciona al menos una factura para procesar el pago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  } // 🏷️ Filtro de fecha compacto

  Widget _filtroFecha() {
    return OutlinedButton.icon(
      onPressed: _seleccionarRangoFechasFacturas,
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        _fechaInicio == null
            ? ''
            : '${DateFormat('dd/MM').format(_fechaInicio!)} - ${DateFormat('dd/MM').format(_fechaFin!)}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // 🏷️ Filtro de búsqueda (cliente/factura)
  Widget _filtroBusqueda() {
    return SizedBox(
      width: 80,
      child: TextField(
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'N° Factura',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (value) {
          setState(() {
            _textoBusqueda = value;
          });
        },
      ),
    );
  }

  // 🏷️ Filtro de monto
  Widget _filtroMonto() {
    return SizedBox(
      width: 80,
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          hintText: '# Monto',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (value) {
          setState(() {
            _montoMinimo = double.tryParse(value);
          });
        },
      ),
    );
  }

  //AQUI?
  String _getTextoAbonoInfo(double montoIngresado, double montoTotal) {
    if (montoIngresado <= 0) {
      return 'Ingresa el monto que desea ';
    }

    if (montoIngresado < montoTotal) {
      final diferencia = montoTotal - montoIngresado;
      return '📌 ABONO PARCIAL: Se abonarán \$${montoIngresado.toStringAsFixed(2)} y quedarán pendientes \$${diferencia.toStringAsFixed(2)}';
    } else if (montoIngresado == montoTotal) {
      return '✅ PAGO COMPLETO: Se pagará el monto exacto de \$${montoTotal.toStringAsFixed(2)}';
    } else {
      final excedente = montoIngresado - montoTotal;
      return '💰 PAGO CON EXCEDENTE: Se paga \$${montoTotal.toStringAsFixed(2)} y \$${excedente.toStringAsFixed(2)} irá a abonos';
    }
  }

  /// 💰 PROCESAR PAGO MÚLTIPLE - Mostrar confirmación con lógica dinámica
  /// Sigue el patrón de facturas_tab.dart
  void _procesarPagoMultipleFacturas(
    List<dynamic> facturas,
    double montoIngresado,
    BuildContext context,
  ) {
    debugPrint('🟡 [CONFIRMACION] Mostrando confirmación de pago múltiple');
    debugPrint('   - Monto Ingresado: \$${montoIngresado.toStringAsFixed(2)}');

    // [1] VALIDACIONES BÁSICAS
    if (montoIngresado <= 0) {
      CustomSnackBar.showError(context, 'Ingresa un monto válido');
      return;
    }

    final facturasSeleccionadas = facturas
        .where((f) => _facturasSeleccionadasParaPago[f.id] ?? false)
        .toList();

    if (facturasSeleccionadas.isEmpty) {
      CustomSnackBar.showError(context, 'Selecciona al menos una factura');
      return;
    }

    // [2] OBTENER SERVICIOS ANTES DE ABRIR DIÁLOGO (IMPORTANTE PARA EVITAR CONTEXTO DESACTIVADO)
    final authService = Provider.of<AuthService>(context, listen: false);
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );
    final pagosService = Provider.of<PagosService>(context, listen: false);

    // [3] CALCULAR TOTALES
    final totalPendiente = facturasSeleccionadas.fold<double>(
      0,
      (sum, f) => sum + (f.saldoPendiente ?? f.total ?? 0),
    );

    final diferencia = montoIngresado - totalPendiente;

    debugPrint('   - Total Pendiente: \$${totalPendiente.toStringAsFixed(2)}');
    debugPrint('   - Diferencia: \$${diferencia.toStringAsFixed(2)}');

    // [3] DETERMINAR TIPO DE OPERACIÓN (para UI y logs)
    late String tipoOperacion;
    late String mensajeAdvertencia;
    late String mensajeResultado;
    late IconData icono;
    late Color colorIcono;

    if (montoIngresado < totalPendiente) {
      // ABONO PARCIAL
      tipoOperacion = 'ABONO_PARCIAL';
      icono = Icons.account_balance_wallet;
      colorIcono = Colors.orange;
      mensajeAdvertencia =
          'El monto ingresado es MENOR al valor total pendiente.\n\n'
          'Este valor se registrará como un ABONO PARCIAL.\n\n'
          '✅ Recibirás: "Se han abonado \$${montoIngresado.toStringAsFixed(2)} a tu cuenta"';
      mensajeResultado = 'Tu abono quedará disponible para futuras facturas.';
    } else if (diferencia > 0.01) {
      // PAGO CON EXCEDENTE
      tipoOperacion = 'EXCEDENTE';
      icono = Icons.check_circle;
      colorIcono = Colors.green;
      final montoAbono = diferencia;
      mensajeAdvertencia =
          'El monto ingresado es MAYOR al valor total pendiente.\n\n'
          '✅ Recibirás: "Facturas pagadas \$${totalPendiente.toStringAsFixed(2)} | '
          'Abonado a cuenta \$${montoAbono.toStringAsFixed(2)}"\n\n'
          'El excedente se registrará como anticipos en tu cuenta.';
      mensajeResultado =
          'Las facturas serán pagadas y el sobrante disponible para futuras compras.';
    } else {
      // PAGO COMPLETO
      tipoOperacion = 'PAGO_COMPLETO';
      icono = Icons.check_circle;
      colorIcono = Colors.blue;
      mensajeAdvertencia =
          'El monto ingresado coincide exactamente con el valor total pendiente.\n\n'
          '✅ Recibirás: "Facturas pagadas exitosamente"\n\n'
          'Las facturas serán canceladas en su totalidad.';
      mensajeResultado =
          'Tu deuda con estas facturas será completamente saldada.';
    }

    debugPrint('   → Tipo de operación: $tipoOperacion');

    // [4] MOSTRAR CONFIRMACIÓN
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icono, color: colorIcono),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirmar Pago Múltiple')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mensaje principal
                Text(mensajeAdvertencia, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                const Divider(),

                // Detalle de facturas
                const Text(
                  'Facturas a procesar:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...facturasSeleccionadas.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Factura #${f.numeroFactura}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '\$${(f.saldoPendiente ?? f.total ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total a pagar:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${totalPendiente.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monto a procesar:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${montoIngresado.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorIcono,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorIcono.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorIcono.withOpacity(0.3)),
                  ),
                  child: Text(
                    mensajeResultado,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorIcono,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _iniciarPagoConTarjetaMultiple(
                  facturasSeleccionadas,
                  montoIngresado,
                  tipoOperacion,
                  authService,
                  facturasService,
                  pagosService,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              icon: const Icon(Icons.credit_card),
              label: const Text('Pagar con Tarjeta'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _ejecutarPagoMultiple(
                  facturasSeleccionadas,
                  montoIngresado,
                  tipoOperacion,
                  authService,
                  facturasService,
                  pagosService,
                  metodoPago: 'transferencia',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmar Pago'),
            ),
          ],
        );
      },
    );
  }

  void _procesarPagoExacto(
    List<dynamic> facturasSeleccionadas,
    double montoIngresado,
    BuildContext context,
  ) {
    // Usar el mismo método de procesamiento
    _procesarPagoMultipleFacturas(
      facturasSeleccionadas,
      montoIngresado,
      context,
    );
  }

  /// 💳 INICIAR PAGO CON TARJETA PARA MÚLTIPLES FACTURAS
  void _iniciarPagoConTarjetaMultiple(
    List<dynamic> facturasSeleccionadas,
    double montoIngresado,
    String tipoOperacion,
    AuthService authService,
    FacturasService facturasService,
    PagosService pagosService,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PagoTarjetaPage(
          monto: montoIngresado,
          origen: 'credito_abono_multiple',
          onTokenGenerado: (token) async {
            // Ahora los servicios ya están obtenidos y el context es válido
            await _ejecutarPagoMultiple(
              facturasSeleccionadas,
              montoIngresado,
              tipoOperacion,
              authService,
              facturasService,
              pagosService,
              metodoPago: 'tarjeta',
            );
          },
        ),
      ),
    );
  }

  /// 💰 EJECUTAR PAGO MÚLTIPLE - Enviar al backend y procesar respuesta
  /// Sigue el patrón de _procesarPagoFactura de facturas_tab.dart
  Future<void> _ejecutarPagoMultiple(
    List<dynamic> facturasSeleccionadas,
    double montoIngresado,
    String tipoOperacionEsperado,
    AuthService authService,
    FacturasService facturasService,
    PagosService pagosService, {
    String metodoPago = 'transferencia',
  }) async {
    debugPrint('🟢 [PROCESAMIENTO] Iniciando pago de múltiples facturas');
    debugPrint('   - Total facturas: ${facturasSeleccionadas.length}');
    debugPrint('   - Monto total: \$${montoIngresado.toStringAsFixed(2)}');
    debugPrint('   - Tipo esperado: $tipoOperacionEsperado');

    try {
      // Ya tenemos los servicios como parámetros, no necesitamos Provider.of()

      double montoRestante = montoIngresado;
      double totalAbonado = 0;
      double totalAnticiposGenerados = 0;
      String? ultimoError;
      int facturasProcessadas = 0;
      int facturasExitosas = 0;

      // [1] PROCESAR CADA FACTURA SELECCIONADA
      debugPrint('   [1] Procesando facturas...');
      for (final factura in facturasSeleccionadas) {
        if (montoRestante <= 0) break;

        // Calcular el monto para esta factura
        final montoParaEstafactura = montoRestante >= factura.saldoPendiente
            ? factura.saldoPendiente
            : montoRestante;

        facturasProcessadas++;

        try {
          debugPrint(
            '   📌 Factura #${factura.numeroFactura}: \$${montoParaEstafactura.toStringAsFixed(2)}',
          );

          // [2] LLAMAR AL BACKEND (PagosService)
          final resultado = await pagosService.pagarFactura(
            facturaId: factura.id,
            monto: montoParaEstafactura,
            metodoPago: metodoPago,
          );

          debugPrint('   ✓ Respuesta: ${resultado.exito}');

          // [3] PROCESAR RESPUESTA
          if (resultado.exito) {
            totalAbonado += montoParaEstafactura;
            montoRestante -= montoParaEstafactura;
            facturasExitosas++;

            debugPrint('   ✅ ÉXITO: Factura pagada');
            debugPrint(
              '   💰 Monto restante: \$${montoRestante.toStringAsFixed(2)}',
            );
          } else {
            ultimoError = resultado.mensaje ?? 'Error desconocido';
            debugPrint('   ❌ ERROR: $ultimoError');
          }
        } catch (e, stackTrace) {
          ultimoError = 'Error procesando factura ${factura.numeroFactura}';
          debugPrint('   🔴 EXCEPCIÓN: $e');
          debugPrint('   Stack: $stackTrace');
        }
      }

      // [1.5] SI HAY EXCEDENTE, CREAR ABONO (ANTICIPOS)
      if (montoRestante > 0.01 && facturasExitosas > 0) {
        debugPrint('   [1.5] Procesando excedente como Abono...');
        debugPrint(
          '   💰 Excedente a convertir en Abono: \$${montoRestante.toStringAsFixed(2)}',
        );

        try {
          // Usar la factura pagada como referencia para registrar el abono
          final facturaPagada = facturasSeleccionadas.firstWhere(
            (f) => totalAbonado >= (f.saldoPendiente ?? f.total ?? 0),
            orElse: () => facturasSeleccionadas.first,
          );

          // Enviar el excedente como abono/anticipo al backend
          // El backend detectará que es un pago >= saldo y creará automáticamente el anticipo
          final resultadoAbono = await pagosService.pagarFactura(
            facturaId: facturaPagada.id,
            monto: montoRestante,
            metodoPago: metodoPago,
          );

          if (resultadoAbono.exito) {
            totalAnticiposGenerados = montoRestante;
            montoRestante = 0;
            debugPrint(
              '   ✅ ÉXITO: Abono creado por \$${totalAnticiposGenerados.toStringAsFixed(2)}',
            );
          } else {
            debugPrint(
              '   ⚠️ Abono no se pudo crear: ${resultadoAbono.mensaje}',
            );
          }
        } catch (e) {
          debugPrint('   🔴 Error creando abono: $e');
        }
      }

      // [4] ACTUALIZAR DATOS LOCALES TRAS ÉXITO
      debugPrint('   [4] Actualizando datos locales...');

      // IMPORTANTE: Actualizar cliente ANTES que facturas para tener datos frescos
      debugPrint('   🔄 Actualizando cliente...');
      await authService.actualizarClienteActual();

      // Esperar un poco para asegurar que se actualicen los datos en el backend
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('   🔄 Refrescando facturas...');
      await facturasService.fetchFacturas(
        clienteId: authService.clienteActual?.id,
        esAdmin: authService.esInstalador,
      );

      // Verificar que el cliente tenga los nuevos abonos
      debugPrint('   📊 Cliente actualizado: ');
      debugPrint(
        '      - Saldo Anticipos: \$${authService.clienteActual?.anticipos?.toStringAsFixed(2) ?? "0.00"}',
      );
      debugPrint('      - Nombre: ${authService.clienteActual?.nombre}');

      // Limpiar UI
      _facturasSeleccionadasParaPago.clear();
      _montoController.clear();

      // Notificar cambio de datos para actualizar UI
      if (mounted) {
        setState(() {});
      }

      // [5] MOSTRAR RESULTADO AL USUARIO
      if (mounted) {
        if (facturasExitosas > 0) {
          // ✅ ÉXITO - Construir mensaje personalizado según tipo
          String mensaje = '';
          String detalleExtra = '';

          if (tipoOperacionEsperado == 'ABONO_PARCIAL') {
            // El monto va a Abonos (Anticipos en BD)
            mensaje = '💰 Abono Registrado';
            final abonos = authService.clienteActual?.anticipos ?? 0.0;
            detalleExtra =
                'Se han abonado \$${montoIngresado.toStringAsFixed(2)} a tu cuenta\n'
                '📊 Saldo Abonos: \$${abonos.toStringAsFixed(2)}';
          } else if (tipoOperacionEsperado == 'EXCEDENTE') {
            // Parte va a pago y parte a abonos
            final totalPendiente = facturasSeleccionadas.fold<double>(
              0,
              (sum, f) => sum + (f.saldoPendiente ?? f.total ?? 0),
            );
            final montoAbono = montoIngresado - totalPendiente;
            final abonos = authService.clienteActual?.anticipos ?? 0.0;
            mensaje = '💵 Pago con Abonos';

            debugPrint('   📊 Detalles del pago excedente:');
            debugPrint(
              '      - Total pendiente: \$${totalPendiente.toStringAsFixed(2)}',
            );
            debugPrint(
              '      - Monto abono generado: \$${montoAbono.toStringAsFixed(2)}',
            );
            debugPrint(
              '      - Saldo abonos total: \$${abonos.toStringAsFixed(2)}',
            );

            detalleExtra =
                '✅ Facturas pagadas: \$${totalPendiente.toStringAsFixed(2)}\n'
                '💰 Abonado a tu cuenta: \$${montoAbono.toStringAsFixed(2)}\n'
                '📊 Saldo Abonos Total: \$${abonos.toStringAsFixed(2)}';
          } else {
            // Pago completo
            mensaje = '✅ Facturas Pagadas';
            detalleExtra =
                '${facturasExitosas} factura${facturasExitosas > 1 ? 's' : ''} pagada${facturasExitosas > 1 ? 's' : ''} por \$${totalAbonado.toStringAsFixed(2)}';
          }

          // Agregar advertencia si no todas fueron exitosas
          if (facturasExitosas < facturasSeleccionadas.length &&
              ultimoError != null) {
            detalleExtra += '\n⚠️ Advertencia: $ultimoError';
          }

          debugPrint('   ✅ ÉXITO: $detalleExtra');
          CustomSnackBar.showPaymentSuccess(context, detalleExtra);

          // Volver a vista principal después de 1.5 segundos
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _vistaActual = 0;
              });
            }
          });
        } else {
          // ❌ FALLO - Mostrar error
          String errorMsg = ultimoError ?? 'No se pudo procesar el pago';
          debugPrint('   ❌ ERROR: $errorMsg');
          // Verificar que el widget siga montado ANTES de mostrar el error
          if (mounted) {
            // Usar post frame callback para evitar el error de deactivated widget
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                CustomSnackBar.showError(context, '❌ $errorMsg');
              }
            });
          }
        }
      } else {
        debugPrint('   ⚠️ Widget no montado al finalizar');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ERROR CRÍTICO] Excepción en _ejecutarPagoMultiple');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');

      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.split('Exception:').last.trim();
        }
        debugPrint('   → Mostrando error: $errorMsg');
        // Usar post frame callback para evitar el error de deactivated widget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            CustomSnackBar.showError(context, '❌ $errorMsg');
          }
        });
      }
    }
  }
}

// Widget personalizado para el gráfico circular de crédito
class CreditoCircularChart extends StatefulWidget {
  final double cupoTotal;
  final double cupoUtilizado;
  final double saldoDisponible;

  const CreditoCircularChart({
    super.key,
    required this.cupoTotal,
    required this.cupoUtilizado,
    required this.saldoDisponible,
  });

  @override
  State<CreditoCircularChart> createState() => _CreditoCircularChartState();
}

class SemiCircularGaugePainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  SemiCircularGaugePainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, backgroundPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(SemiCircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CreditoCircularChartState extends State<CreditoCircularChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    final porcentajeUtilizado = widget.cupoTotal > 0
        ? widget.cupoUtilizado / widget.cupoTotal
        : 0.0;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: porcentajeUtilizado.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _glowAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 8),

          const Text(
            'Cupo utilizado',
            style: TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // 🔥 TEXTO CON BRILLO ANIMADO
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _glowAnimation.value,
                child: Text(
                  '\$${widget.cupoUtilizado.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                    shadows: [Shadow(blurRadius: 14, color: Color(0x55D32F2F))],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 🎯 GAUGE SEMICIRCULAR CON OVERLAY DE DATOS
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return SizedBox(
                    width: 240,
                    height: 120,
                    child: CustomPaint(
                      painter: SemiCircularGaugePainter(
                        progress: _progressAnimation.value,
                        backgroundColor: Colors.grey.shade300,
                        progressColor: const Color(0xFFD32F2F),
                        strokeWidth: 14,
                      ),
                    ),
                  );
                },
              ),
              // 💰 ABONO (superior izquierda - invadiendo gráfico)
              // 📊 CUPO DISPONIBLE (debajo de abono - invadiendo gráfico)
              Positioned(
                top: 70,
                left: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cupo disponible',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${widget.saldoDisponible.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 20,
                left: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cupo autorizado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${widget.cupoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                return Stack(
                  children: [
                    // 🔹 0 (inicio)
                    Positioned(
                      left: width * 0.09, // 5% del ancho
                      top: 0,
                      child: const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // 🔹 ABONOS
                    Positioned(
                      left: width * 0.35, // 35% del ancho
                      top: 0,
                      child: Consumer<AuthService>(
                        builder: (context, authService, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ABONOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '\$${(authService.clienteActual?.anticipos ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🔹 Cupo total
                    Positioned(
                      right: width * 0.05, // 5% del ancho desde la derecha
                      top: 0,
                      child: Text(
                        '\$${widget.cupoTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
