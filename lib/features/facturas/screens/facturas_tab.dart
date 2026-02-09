import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/pagos_service.dart';
import '../../../models/factura.dart';
import '../../../models/pago.dart';
import '../../../core/widgets/custom_overlay_notification.dart';
import '../../../core/widgets/custom_confirm_dialog.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/anticipos_card.dart';
import '../../../core/services/navigation_service.dart';
import '../../../screens/main_screen.dart';
import 'factura_detalle_screen.dart';
import '../../../core/logs/app_logger.dart';
import '../../pagos/screens/pago_tarjeta_page.dart';

enum EstadoVencimiento { normal, proximaVencer, vencida }

class FacturasTab extends StatefulWidget {
  final bool modoAbonoMultiple;
  final double montoPreconfigurado;

  const FacturasTab({
    super.key,
    this.modoAbonoMultiple = false,
    this.montoPreconfigurado = 0,
  });

  @override
  State<FacturasTab> createState() => _FacturasTabState();
}

class _FacturasTabState extends State<FacturasTab>
    with RouteAware, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final _searchController = TextEditingController();
  String _queryBusqueda = '';

  // Paginación
  int _paginaActual = 1;
  final int _facturasPorPagina = 10;

  // Filtros de fecha
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Filtro de estado
  String?
  _estadoSeleccionado; // null = todos, 'pendiente', 'emitida', 'pagada', 'anulada'

  // 💰 ABONO MÚLTIPLE - Rastrear facturas seleccionadas
  final Map<int, bool> _facturasSeleccionadas = {};
  bool _mostrarCheckboxes = false;

  // 💳 Método de pago para abono a anticipos
  String metodoPagoAbono = 'transferencia';

  @override
  void initState() {
    super.initState();
    // Escuchar estado de ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
  }

  /// Seleccionar automáticamente facturas que se pueden pagar con el monto preconfigurado
  void _seleccionarFacturasAutomaticamente() {
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );
    final facturasPendientes = facturasService.facturas
        .where((f) => f.saldoPendiente > 0 && f.estado == 'emitida')
        .toList();

    double montoDisponible = widget.montoPreconfigurado;
    _facturasSeleccionadas.clear();

    // Ordenar por fecha de emisión (más recientes primero)
    facturasPendientes.sort((a, b) {
      final fechaAEmision = a.fechaEmision ?? DateTime(1980);
      final fechaBEmision = b.fechaEmision ?? DateTime(1980);

      // Primero por fecha de emisión (descendente - más recientes primero)
      final comparacionEmision = fechaBEmision.compareTo(fechaAEmision);
      if (comparacionEmision != 0) return comparacionEmision;

      // Si tienen la misma fecha de emisión, ordenar por vencimiento
      return (a.fechaVencimiento ?? DateTime(2099)).compareTo(
        b.fechaVencimiento ?? DateTime(2099),
      );
    });

    // Seleccionar facturas que se pueden cubrir
    for (var factura in facturasPendientes) {
      if (montoDisponible >= factura.saldoPendiente) {
        _facturasSeleccionadas[factura.id] = true;
        montoDisponible -= factura.saldoPendiente;
      } else if (montoDisponible > 0) {
        // Si queda dinero pero no alcanza para una factura completa, seleccionar esta también
        _facturasSeleccionadas[factura.id] = true;
        montoDisponible = 0;
        break;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Unsubscribe RouteObserver
    try {
      final route = ModalRoute.of(context);
      if (route != null) routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suscribir al RouteObserver para detectar cuando la pantalla vuelve a ser visible
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  // RouteAware callbacks
  @override
  void didPush() {
    // pantalla fue empujada -> cargar facturas
    if (mounted) {
      _refreshFacturas();
      // Si hay monto preconfigurado, mostrar checkboxes y seleccionar automáticamente
      if (widget.modoAbonoMultiple && widget.montoPreconfigurado > 0) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _mostrarCheckboxes = true;
            });
            _seleccionarFacturasAutomaticamente();
          }
        });
      }
      debugPrint(
        '🟢 [DIDPUSH] Pantalla de facturas mostrada, refrescando datos...',
      );
    }
  }

  @override
  void didPopNext() {
    // Volvió a esta pantalla desde otra encima -> refrescar
    if (mounted) {
      debugPrint(
        '🟠 [DIDPOPNEXT] Volviendo a pantalla de facturas, refrescando datos...',
      );
      _refreshFacturas();
    }
  }

  // App lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // La app volvió a foreground -> refrescar
      _refreshFacturas();
    }
  }

  void _refreshFacturas() {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    // No intentar cargar si no hay usuario logueado
    if (authService.clienteActual == null) return;

    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );

    facturasService.fetchFacturas(
      clienteId: authService.clienteActual?.id,
      esAdmin: authService.esInstalador,
    );
  }

  void _filtrarFacturas(String query) {
    setState(() {
      _queryBusqueda = query;
      _paginaActual = 1; // Reiniciar a página 1 al buscar
    });
  }

  // 💰 Toggle para seleccionar/deseleccionar todas las facturas
  void _toggleSeleccionarTodo() {
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );

    final facturasDisponibles = facturasService.facturas
        .where((f) => f.saldoPendiente > 0 && f.estado == 'emitida')
        .toList();

    final todasSeleccionadas = facturasDisponibles.every(
      (f) => _facturasSeleccionadas[f.id] == true,
    );

    setState(() {
      for (final factura in facturasDisponibles) {
        _facturasSeleccionadas[factura.id] = !todasSeleccionadas;
      }
    });
  }

  Future<void> _seleccionarRangoFechas() async {
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
      saveText: 'Guardar',
      fieldStartLabelText: 'Fecha inicio',
      fieldEndLabelText: 'Fecha fin',
      errorFormatText: 'Formato inválido',
      errorInvalidText: 'Fecha inválida',
      errorInvalidRangeText: 'Rango inválido',
      fieldStartHintText: 'dd/mm/aaaa',
      fieldEndHintText: 'dd/mm/aaaa',
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
        _paginaActual = 1; // Reiniciar a página 1 al aplicar filtro
      });
    }
  }

  void _limpiarFiltroFechas() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _estadoSeleccionado = null;
      _paginaActual = 1;
    });
  }

  List<Factura> _aplicarFiltrosFechas(List<Factura> facturas) {
    if (_fechaInicio == null || _fechaFin == null) return facturas;

    return facturas.where((factura) {
      final fecha = factura.fechaEmision;
      if (fecha == null) return false;
      return fecha.isAfter(_fechaInicio!.subtract(const Duration(days: 1))) &&
          fecha.isBefore(_fechaFin!.add(const Duration(days: 1)));
    }).toList();
  }

  List<Factura> _aplicarFiltroEstado(List<Factura> facturas) {
    if (_estadoSeleccionado == null) return facturas;
    return facturas.where((f) => f.estado == _estadoSeleccionado).toList();
  }

  void _showPagoDialog(
    Factura factura,
    PagosService pagosService,
    FacturasService facturasService,
    AuthService authService,
  ) {
    debugPrint(
      '🔵 [PAGO] Iniciando _showPagoDialog para factura #${factura.numeroFactura}',
    );
    debugPrint('   - Factura ID: ${factura.id}');
    debugPrint(
      '   - Saldo Pendiente: \$${factura.saldoPendiente.toStringAsFixed(2)}',
    );

    final montoController = TextEditingController(
      text: factura.saldoPendiente.toStringAsFixed(2),
    );
    String metodoPago = 'transferencia';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        ' Pagar Factura',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Información de la factura
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factura ${factura.numeroFactura}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo Pendiente:'),
                            Text(
                              '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Monto a pagar
                  Text(
                    'Monto a Pagar',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: montoController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),

                  // Información dinámica de abono
                  if (montoController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildInformacionAbonoPago(
                        double.tryParse(montoController.text) ?? 0,
                        factura.saldoPendiente,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Método de pago
                  Text(
                    'Método de Pago',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: metodoPago,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => metodoPago = value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferencia Bancaria'),
                      ),
                      DropdownMenuItem(
                        value: 'efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'tarjeta',
                        child: Text('Tarjeta de Crédito'),
                      ),
                    ],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final monto = double.tryParse(
                              montoController.text.trim(),
                            );

                            if (monto == null || monto <= 0) {
                              CustomOverlayNotification.showWarning(
                                context,
                                'Ingresa un monto válido',
                              );
                              return;
                            }

                            Navigator.pop(context);

                            // Si es pago con tarjeta, usar PagoTarjetaPage
                            if (metodoPago == 'tarjeta') {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PagoTarjetaPage(
                                    monto: monto,
                                    origen: 'facturas_tab_pago',
                                    onTokenGenerado: (token) async {
                                      // Procesar pago con el token
                                      await _procesarPagoFactura(
                                        factura,
                                        monto,
                                        metodoPago,
                                        pagosService,
                                        facturasService,
                                        authService,
                                      );
                                    },
                                  ),
                                ),
                              );
                            } else {
                              // Mostrar confirmación con lógica dinámica
                              _mostrarConfirmacionPago(
                                factura,
                                monto,
                                metodoPago,
                                pagosService,
                                facturasService,
                                authService,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Procesar Pago',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Aviso legal
                  Text(
                    '✓ Todos los datos se envían encriptados\n'
                    '✓ Recibirás confirmación por correo\n'
                    '✓ El cambio se refleja inmediatamente',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper para mostrar información dinámica del abono
  Widget _buildInformacionAbonoPago(double monto, double saldoPendiente) {
    final diferencia = monto - saldoPendiente;

    if (diferencia.abs() < 0.01) {
      // Pago exacto
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Factura será completamente pagada',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      );
    } else if (diferencia > 0) {
      // Excedente
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Pago con Excedente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo pendiente: \$${saldoPendiente.toStringAsFixed(2)}\n'
              'Monto pagado: \$${monto.toStringAsFixed(2)}\n'
              'Excedente (a anticipos): \$${diferencia.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ],
        ),
      );
    } else {
      // Abono parcial
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Abono Parcial',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo pendiente: \$${saldoPendiente.toStringAsFixed(2)}\n'
              'Abonarás: \$${monto.toStringAsFixed(2)}\n'
              'Nuevo saldo: \$${(saldoPendiente - monto).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],
        ),
      );
    }
  }

  // Mostrar confirmación de pago con lógica dinámica
  void _mostrarConfirmacionPago(
    Factura factura,
    double montoIngresado,
    String metodoPago,
    PagosService pagosService,
    FacturasService facturasService,
    AuthService authService,
  ) {
    debugPrint('🟡 [CONFIRMACION] Mostrando confirmación de pago');
    debugPrint('   - Monto Ingresado: \$${montoIngresado.toStringAsFixed(2)}');
    debugPrint(
      '   - Saldo Pendiente: \$${factura.saldoPendiente.toStringAsFixed(2)}',
    );
    debugPrint('   - Método: $metodoPago');

    showDialog(
      context: context,
      builder: (context) {
        final diferencia = montoIngresado - factura.saldoPendiente;

        // Mensaje dinámico según el tipo de operación
        late String mensajeAdvertencia;
        late String mensajeResultado;
        late IconData icono;
        late Color colorIcono;

        if (montoIngresado < factura.saldoPendiente) {
          icono = Icons.account_balance_wallet;
          colorIcono = Colors.orange;
          mensajeAdvertencia =
              'El monto ingresado es MENOR al valor total pendiente.\n\n'
              'Este valor se registrará como un ABONO PARCIAL.\n\n'
              '✅ Recibirás: "Se han abonado \$${montoIngresado.toStringAsFixed(2)} a tu cuenta"';
          mensajeResultado =
              'Tu abono quedará disponible para futuras facturas.';
        } else if (diferencia > 0.01) {
          icono = Icons.check_circle;
          colorIcono = Colors.green;
          final montoPago = factura.saldoPendiente;
          final montoAbono = montoIngresado - factura.saldoPendiente;
          mensajeAdvertencia =
              'El monto ingresado es MAYOR al valor total pendiente.\n\n'
              '✅ Recibirás: "Factura pagada \$${montoPago.toStringAsFixed(2)} | '
              'Abonado a cuenta \$${montoAbono.toStringAsFixed(2)}"\n\n'
              'El excedente se registrará como anticipos en tu cuenta.';
          mensajeResultado =
              'La factura será pagada y el sobrante disponible para futuras compras.';
        } else {
          icono = Icons.check_circle;
          colorIcono = Colors.blue;
          mensajeAdvertencia =
              'El monto ingresado coincide exactamente con el valor total pendiente.\n\n'
              '✅ Recibirás: "Factura pagada exitosamente"\n\n'
              'La factura será cancelada en su totalidad.';
          mensajeResultado =
              'Tu deuda con esta factura será completamente saldada.';
        }

        return AlertDialog(
          title: Row(
            children: [
              Icon(icono, color: colorIcono),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirmar Pago')),
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

                // Detalle de factura
                const Text(
                  'Detalle de factura:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Factura #${factura.numeroFactura}'),
                    Text(
                      '\$${factura.saldoPendiente.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monto a procesar:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${montoIngresado.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorIcono,
                        fontSize: 16,
                      ),
                    ),
                  ],
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Si es pago con tarjeta, usar PagoTarjetaPage
                if (metodoPago == 'tarjeta') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PagoTarjetaPage(
                        monto: montoIngresado,
                        origen: 'facturas_tab_confirmacion',
                        onTokenGenerado: (token) async {
                          // Procesar pago con el token
                          await _procesarPagoFactura(
                            factura,
                            montoIngresado,
                            metodoPago,
                            pagosService,
                            facturasService,
                            authService,
                          );
                        },
                      ),
                    ),
                  );
                } else {
                  await _procesarPagoFactura(
                    factura,
                    montoIngresado,
                    metodoPago,
                    pagosService,
                    facturasService,
                    authService,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmar Pago'),
            ),
          ],
        );
      },
    );
  }

  // Procesar el pago usando PagosService (igual a PagoFacturaModal)
  Future<void> _procesarPagoFactura(
    Factura factura,
    double monto,
    String metodoPago,
    PagosService pagosService,
    FacturasService facturasService,
    AuthService authService,
  ) async {
    debugPrint('🟢 [PROCESAMIENTO] Iniciando _procesarPagoFactura');
    debugPrint('   - Factura ID: ${factura.id}');
    debugPrint('   - Monto Ingresado: \$${monto.toStringAsFixed(2)}');
    debugPrint(
      '   - Saldo Pendiente: \$${factura.saldoPendiente.toStringAsFixed(2)}',
    );
    debugPrint('   - Método de Pago: $metodoPago');

    AppLogger.logInfo(
      'Iniciando procesamiento de pago - Factura: ${factura.numeroFactura}',
    );
    AppLogger.logInfo(
      'Monto: \$${monto.toStringAsFixed(2)} | Método: $metodoPago',
    );

    try {
      // Determinar tipo de operación según el monto
      final diferencia = monto - factura.saldoPendiente;

      late String tipoOperacion;

      if (monto < factura.saldoPendiente) {
        debugPrint('   → Procesando ABONO PARCIAL (monto < saldo)');
        AppLogger.logInfo(
          'Procesando ABONO PARCIAL - Saldo: \$${factura.saldoPendiente.toStringAsFixed(2)}, Monto: \$${monto.toStringAsFixed(2)}',
        );
        tipoOperacion = 'ABONO_PARCIAL';
      } else if (diferencia > 0.01) {
        debugPrint('   → Procesando PAGO CON EXCEDENTE (monto > saldo)');
        AppLogger.logInfo(
          'Procesando PAGO CON EXCEDENTE - Saldo: \$${factura.saldoPendiente.toStringAsFixed(2)}, Monto: \$${monto.toStringAsFixed(2)}',
        );
        tipoOperacion = 'EXCEDENTE';
      } else {
        debugPrint('   → Procesando PAGO COMPLETO (monto ≈ saldo)');
        AppLogger.logInfo('Procesando PAGO COMPLETO');
        tipoOperacion = 'PAGO_COMPLETO';
      }

      // Llamar al servicio de pago
      // El backend detectará automáticamente el tipo de operación (ABONO_PARCIAL, PAGO_COMPLETO o EXCEDENTE)
      final resultado = await pagosService.pagarFactura(
        facturaId: factura.id,
        monto: monto,
        metodoPago: metodoPago,
      );

      debugPrint('   ✓ Resultado de pago recibido: ${resultado.exito}');
      debugPrint('   - Tipo de operación: ${resultado.tipoOperacion}');
      debugPrint('   - Mensaje: ${resultado.mensaje}');

      AppLogger.logInfo(
        'Resultado de pago: ${resultado.exito ? "EXITOSO" : "FALLIDO"}',
      );
      AppLogger.logDebug('Tipo de operación: ${resultado.tipoOperacion}');
      AppLogger.logDebug('Mensaje: ${resultado.mensaje}');

      if (mounted) {
        if (resultado.exito) {
          debugPrint('   ✓ Pago exitoso, actualizando facturas...');

          AppLogger.logInfo(
            '✅ Pago procesado exitosamente - Actualizando facturas',
          );

          // Actualizar facturas y cliente
          await facturasService.fetchFacturas(
            clienteId: authService.clienteActual?.id,
            esAdmin: authService.esInstalador,
          );

          // Actualizar datos del cliente para reflejar anticipos
          await authService.actualizarClienteActual();

          // Mostrar mensaje de éxito personalizado según el tipo de operación
          String mensaje = '';
          String detalleSubtitulo = '';

          if (tipoOperacion == 'ABONO_PARCIAL') {
            // 💰 TODO el monto va a anticipos
            // Agregar el monto completo al campo ANTICIPOS
            final anticiposActuales =
                authService.clienteActual?.anticipos ?? 0.0;
            final nuevosAnticipos = anticiposActuales + monto;

            // Actualizar el campo anticipos en la sesión actual
            authService.actualizarClienteAnticipos(nuevosAnticipos);

            debugPrint('   💰 Agregando abono parcial a Anticipos:');
            debugPrint(
              '      - Anticipos anteriores: \$${anticiposActuales.toStringAsFixed(2)}',
            );
            debugPrint('      - Abono agregado: \$${monto.toStringAsFixed(2)}');
            debugPrint(
              '      - Nuevos Anticipos: \$${nuevosAnticipos.toStringAsFixed(2)}',
            );

            mensaje = '💰 Abono Registrado';
            detalleSubtitulo =
                'Se han abonado \$${monto.toStringAsFixed(2)} a tu cuenta\n'
                '📊 Saldo Anticipos: \$${nuevosAnticipos.toStringAsFixed(2)}';
            debugPrint('   ✅ ÉXITO: $detalleSubtitulo');

            CustomSnackBar.showPaymentSuccess(context, detalleSubtitulo);
          } else if (tipoOperacion == 'EXCEDENTE') {
            // Parte va a pago y parte a abonos
            final montoPago = factura.saldoPendiente;
            final montoAbono = monto - factura.saldoPendiente;

            // 💰 AGREGAR EL EXCEDENTE AL CAMPO ANTICIPOS
            final anticiposActuales =
                authService.clienteActual?.anticipos ?? 0.0;
            final nuevosAnticipos = anticiposActuales + montoAbono;

            // Actualizar el campo anticipos en la sesión actual
            authService.actualizarClienteAnticipos(nuevosAnticipos);

            debugPrint('   💰 Agregando excedente a Anticipos:');
            debugPrint(
              '      - Anticipos anteriores: \$${anticiposActuales.toStringAsFixed(2)}',
            );
            debugPrint(
              '      - Excedente agregado: \$${montoAbono.toStringAsFixed(2)}',
            );
            debugPrint(
              '      - Nuevos Anticipos: \$${nuevosAnticipos.toStringAsFixed(2)}',
            );

            mensaje = '💵 Pago con Anticipos';
            detalleSubtitulo =
                '✅ Factura pagada \$${montoPago.toStringAsFixed(2)}\n'
                '✅ Abonado a cuenta \$${montoAbono.toStringAsFixed(2)}\n'
                '📊 Saldo Anticipos: \$${nuevosAnticipos.toStringAsFixed(2)}';
            debugPrint('   ✅ ÉXITO: $detalleSubtitulo');

            CustomSnackBar.showPaymentSuccess(context, detalleSubtitulo);
          } else {
            // Pago completo
            mensaje = '✅ Factura Pagada';
            detalleSubtitulo =
                'Factura #${factura.numeroFactura} pagada exitosamente';
            debugPrint('   ✅ ÉXITO: $detalleSubtitulo');

            CustomSnackBar.showPaymentSuccess(context, detalleSubtitulo);
          }
        } else {
          debugPrint('   ❌ ERROR en pago: ${resultado.mensaje}');
          AppLogger.logError('Error en pago: ${resultado.mensaje}');
          CustomOverlayNotification.showError(context, resultado.mensaje);
        }
      } else {
        debugPrint('   ⚠️ Widget no montado al finalizar el pago');
        AppLogger.logWarning('Widget no montado al finalizar el pago');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ERROR] Excepción en _procesarPagoFactura');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');

      AppLogger.logError('Excepción en _procesarPagoFactura', e, stackTrace);

      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.split('Exception:').last.trim();
        }
        debugPrint('   → Mostrando error al usuario: $errorMsg');
        CustomOverlayNotification.showError(context, errorMsg);
      } else {
        debugPrint('   ⚠️ Widget no montado, no se puede mostrar error');
        AppLogger.logWarning(
          'Widget no montado - no se puede mostrar error al usuario',
        );
      }
    }
  }

  // 💰 ABONO A ANTICIPOS - Mostrar diálogo para abonar directamente a anticipos
  void _showAbonoAnticipossDialog() {
    debugPrint('🟠 [ABONO ANTICIPOS] Iniciando _showAbonoAnticipossDialog');

    // Obtener servicios
    final authService = Provider.of<AuthService>(context, listen: false);
    final anticiposActuales = authService.clienteActual?.anticipos ?? 0.0;

    debugPrint(
      '   ✓ Anticipos actuales: \$${anticiposActuales.toStringAsFixed(2)}',
    );

    final montoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abonar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Abono actual
              Column(
                children: [
                  const Text(
                    'Tu abono actual:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  Text(
                    '\$${anticiposActuales.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 225, 221, 0),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Monto a abonar
              const Text(
                'Monto a Abonar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B0F18),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: montoController,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '\$',
                  prefixStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa el monto que deseas abonar a tu cuenta.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),

              // Método de pago
              const Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B0F18),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: metodoPagoAbono,
                onChanged: (value) {
                  setState(() {
                    metodoPagoAbono = value ?? 'transferencia';
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 'transferencia',
                    child: Text('Transferencia Bancaria'),
                  ),
                  DropdownMenuItem(
                    value: 'efectivo',
                    child: Text('Efectivo'),
                  ),
                  DropdownMenuItem(
                    value: 'tarjeta',
                    child: Text('Tarjeta de Crédito'),
                  ),
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final monto = double.tryParse(montoController.text);
              if (monto == null || monto <= 0) {
                CustomOverlayNotification.showWarning(
                  dialogContext,
                  'Ingresa un monto válido',
                );
                return;
              }

              Navigator.pop(dialogContext);

              // Si es pago con tarjeta, usar PagoTarjetaPage
              if (metodoPagoAbono == 'tarjeta') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PagoTarjetaPage(
                      monto: monto,
                      origen: 'abono_anticipos',
                      onTokenGenerado: (token) async {
                        // Procesar abono con tarjeta
                        await _procesarAbonoAnticiposs(monto);
                      },
                    ),
                  ),
                );
              } else {
                // Mostrar diálogo de confirmación para otros métodos
                _mostrarConfirmacionAbonoAnticiposs(monto, anticiposActuales);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0b0f18),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  // 💰 Mostrar confirmación de abono a anticipos
  void _mostrarConfirmacionAbonoAnticiposs(
    double montoIngresado,
    double anticiposActuales,
  ) {
    debugPrint('🟡 [CONFIRMACION ABONO] Mostrando confirmación de abono');
    debugPrint('   - Monto Ingresado: \$${montoIngresado.toStringAsFixed(2)}');
    debugPrint(
      '   - Anticipos Actuales: \$${anticiposActuales.toStringAsFixed(2)}',
    );

    final nuevoAbono = anticiposActuales + montoIngresado;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirmar Abono')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Deseas abonar \$${montoIngresado.toStringAsFixed(2)} a tu cuenta?',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Detalle:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Abono actual:'),
                    Text(
                      '\$${anticiposActuales.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto a abonar:'),
                    Text(
                      '\$${montoIngresado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nuevo Abono:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '\$${nuevoAbono.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _procesarAbonoAnticiposs(montoIngresado);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmar Abono'),
            ),
          ],
        );
      },
    );
  }

  // 💰 Procesar abono a anticipos
  Future<void> _procesarAbonoAnticiposs(double monto) async {
    debugPrint('🔵 [PROCESAMIENTO ABONO] Iniciando _procesarAbonoAnticiposs');
    debugPrint('   - Monto: \$${monto.toStringAsFixed(2)}');

    AppLogger.logInfo(
      'Iniciando abono a anticipos - Monto: \$${monto.toStringAsFixed(2)}',
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final facturasService = Provider.of<FacturasService>(
        context,
        listen: false,
      );
      final clienteId = authService.clienteActual?.id;

      if (clienteId == null) {
        throw Exception('Cliente no identificado');
      }

      debugPrint('   ✓ Cliente ID: $clienteId');
      AppLogger.logDebug('Cliente ID: $clienteId');

      // Llamar al API para registrar el abono a anticipos
      final response = await _apiService.post('/pagos/abonar-anticipos', {
        'clienteId': clienteId,
        'monto': monto,
      });

      if (response['success'] ?? false) {
        debugPrint('   ✓ Abono registrado exitosamente');
        AppLogger.logInfo('✅ Abono registrado exitosamente');

        // Actualizar los anticipos en el AuthService
        final nuevosAnticiposValue =
            response['data']?['anticiposNuevos'] ?? 0.0;
        final nuevosAnticipos = double.parse(nuevosAnticiposValue.toString());
        authService.actualizarClienteAnticipos(nuevosAnticipos);

        // Refrescar facturas después del abono
        await facturasService.fetchFacturas(
          clienteId: clienteId,
          esAdmin: authService.esInstalador,
        );

        if (mounted) {
          setState(() {});
          final mensaje =
              '✅ Se abonaron \$${monto.toStringAsFixed(2)} exitosamente';
          debugPrint('   ✅ ÉXITO: $mensaje');
          CustomSnackBar.showPaymentSuccess(context, mensaje);
        }
      } else {
        throw Exception(response['message'] ?? 'Error al procesar el abono');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [ERROR] Excepción en _procesarAbonoAnticiposs');
      debugPrint('   - Error: $e');
      debugPrint('   - StackTrace: $stackTrace');

      AppLogger.logError(
        'Excepción en _procesarAbonoAnticiposs',
        e,
        stackTrace,
      );

      if (context.mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.split('Exception:').last.trim();
        }
        debugPrint('   → Mostrando error al usuario: $errorMsg');
        CustomOverlayNotification.showError(context, errorMsg);
      }
    }
  }

  // 💰 Mostrar confirmación de abono múltiple con lógica de credito_tab

  Color _colorEstadoFactura(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagada':
        return Colors.green;
      case 'emitida':
        return Colors.orange;
      case 'pendiente':
        return Colors.blue;
      case 'anulada':
        return Colors.red;
      default:
        return const Color.fromARGB(255, 0, 0, 0);
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final facturasService = Provider.of<FacturasService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ VERIFICAR SI ESTÁ LOGUEADO
    if (!authService.estaLogueado) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 24),
                Text(
                  'Para ver tus facturas inicia sesión primero',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Accede a tu cuenta para consultar el historial de facturas, pagos y estados de tus pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    MainScreenState.cambiarPestanaGlobal(4); // 👈 MI CUENTA
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B0F18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ SI ESTÁ LOGUEADO, MOSTRAR FACTURAS
    final esAdmin = authService.esInstalador;

    // Obtener facturas filtradas por búsqueda - HACER COPIA PARA EVITAR ERRORES DE LISTA INMUTABLE
    var facturasFiltradas = _queryBusqueda.isEmpty
        ? List<Factura>.from(facturasService.facturas)
        : List<Factura>.from(facturasService.buscarFacturas(_queryBusqueda));

    // Aplicar filtro de fechas
    facturasFiltradas = _aplicarFiltrosFechas(facturasFiltradas);

    // Aplicar filtro de estado
    facturasFiltradas = _aplicarFiltroEstado(facturasFiltradas);

    // Si estamos en modo Abono Múltiple, mostrar SOLO facturas pendientes
    if (widget.modoAbonoMultiple && facturasFiltradas.isNotEmpty) {
      facturasFiltradas = facturasFiltradas
          .where((f) => f.saldoPendiente > 0 && f.estado == 'emitida')
          .toList();
    }

    // 📅 Ordenar: pendientes y emitidas primero, luego por fecha de emisión (más recientes primero) en primera página
    if (_paginaActual == 1 && facturasFiltradas.isNotEmpty) {
      facturasFiltradas.sort((a, b) {
        // Prioridad: pendiente=1, emitida=2, otros=3
        int prioridadA = a.estado == 'pendiente'
            ? 1
            : (a.estado == 'emitida' ? 2 : 3);
        int prioridadB = b.estado == 'pendiente'
            ? 1
            : (b.estado == 'emitida' ? 2 : 3);

        // Primero por prioridad ascendente
        final comparacionPrioridad = prioridadA.compareTo(prioridadB);
        if (comparacionPrioridad != 0) return comparacionPrioridad;

        // Si misma prioridad, por fecha de emisión descendente
        final fechaAEmision = a.fechaEmision ?? DateTime(1980);
        final fechaBEmision = b.fechaEmision ?? DateTime(1980);
        final comparacionEmision = fechaBEmision.compareTo(fechaAEmision);
        if (comparacionEmision != 0) return comparacionEmision;

        // Si tienen la misma fecha de emisión, ordenar por vencimiento
        return (a.fechaVencimiento ?? DateTime(2099)).compareTo(
          b.fechaVencimiento ?? DateTime(2099),
        );
      });
    }

    // Aplicar paginación
    final totalFacturas = facturasFiltradas.length;
    final totalPaginas = (totalFacturas / _facturasPorPagina).ceil();
    final startIndex = (_paginaActual - 1) * _facturasPorPagina;
    final endIndex = (startIndex + _facturasPorPagina).clamp(0, totalFacturas);
    final facturasPaginadas = startIndex < totalFacturas
        ? facturasFiltradas.sublist(startIndex, endIndex)
        : <Factura>[];

    return Column(
      children: [
        // Buscador
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF1A1C1E) : Colors.grey.shade100,
          child: Column(
            children: [
              // Barra de búsqueda (solo para admin)
              if (esAdmin)
                TextField(
                  controller: _searchController,
                  onChanged: _filtrarFacturas,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar número de factura o estado...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filtrarFacturas('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2E3440) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              if (esAdmin) const SizedBox(height: 12),
              // Filtros de fecha y estado
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarRangoFechas,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        _fechaInicio != null && _fechaFin != null
                            ? '${_formatearFecha(_fechaInicio!)} - ${_formatearFecha(_fechaFin!)}'
                            : 'Fecha',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dropdown de estado
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _estadoSeleccionado ?? 'todos',
                      isDense: true,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        labelStyle: const TextStyle(fontSize: 10),
                        prefixIcon: const Icon(Icons.filter_list, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2E3440)
                            : Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'todos',
                          child: Text('Todos'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'emitida',
                          child: Text('Emitida'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'pagada',
                          child: Text('Pagada'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'anulada',
                          child: Text('Anulada'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _estadoSeleccionado = value == 'todos' ? null : value;
                          _paginaActual = 1;
                        });
                      },
                    ),
                  ),
                  if (_fechaInicio != null || _estadoSeleccionado != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _limpiarFiltroFechas,
                      tooltip: 'Limpiar filtros',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 💰 Información de Abonos + Botón Abonar (solo en modo Abono)
              if (widget.modoAbonoMultiple)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Abono (solo información, NO es un botón)
                    //ABONO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABONOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(
                              255,
                              203,
                              197,
                              0,
                            ).withOpacity(0.9),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${(authService.clienteActual?.anticipos ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _showAbonoAnticipossDialog,
                          icon: const Icon(
                            Icons.account_balance_wallet,
                            size: 14,
                          ),
                          label: const Text(
                            'Abonar',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            backgroundColor: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Lista de facturas
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => facturasService.fetchFacturas(
              clienteId: authService.clienteActual?.id,
              esAdmin: esAdmin,
            ),
            child: facturasService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : facturasService.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            facturasService.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => facturasService.fetchFacturas(
                              clienteId: authService.clienteActual?.id,
                              esAdmin: esAdmin,
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : facturasFiltradas.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isNotEmpty || _fechaInicio != null
                          ? 'No se encontraron facturas'
                          : 'No hay facturas',
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: facturasPaginadas.length,
                          itemBuilder: (context, index) {
                            final factura = facturasPaginadas[index];
                            final estadoVencimiento = _getEstadoVencimiento(
                              factura,
                            );

                            final isSelected =
                                _facturasSeleccionadas[factura.id] ?? false;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FacturaDetalleScreen(factura: factura),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation:
                                    estadoVencimiento ==
                                        EstadoVencimiento.vencida
                                    ? 4
                                    : 2,
                                color: _getCardColor(estadoVencimiento),
                                child: ListTile(
                                  // 💰 CHECKBOX para abono múltiple
                                  leading: _mostrarCheckboxes
                                      ? Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              _facturasSeleccionadas[factura
                                                      .id] =
                                                  value ?? false;
                                            });
                                          },
                                        )
                                      : Stack(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: _getEstadoColor(
                                                factura.estado,
                                              ),
                                              child: const Icon(
                                                Icons.receipt_long,
                                                color: Colors.white,
                                              ),
                                            ),
                                            // Indicador de vencimiento
                                            if (estadoVencimiento !=
                                                EstadoVencimiento.normal)
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: _getVencimientoColor(
                                                      estadoVencimiento,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          factura.numeroFactura,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (estadoVencimiento ==
                                          EstadoVencimiento.vencida)
                                        _buildBadge('VENCIDA', Colors.red),
                                      if (estadoVencimiento ==
                                          EstadoVencimiento.proximaVencer)
                                        _buildBadge('PRÓXIMO', Colors.orange),
                                    ],
                                  ),

                                  //NEGRILLA EN TEXTO
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Mostrar nombre del cliente si es admin
                                      if (esAdmin && factura.cliente != null)
                                        RichText(
                                          text: TextSpan(
                                            style: DefaultTextStyle.of(context)
                                                .style
                                                .copyWith(
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                ),
                                            children: [
                                              const TextSpan(
                                                text: 'Cliente: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              TextSpan(
                                                text: factura.cliente!.nombre,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold, // 👈 AHORA SÍ SE VE
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      /* if (esAdmin && factura.cliente != null)
                                      Text(
                                        'Cliente: ${factura.cliente!.nombre}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ), */
                                      // 📅 Mostrar fecha de creación/emisión
                                      if (factura.fechaEmision != null)
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Creada: ',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight
                                                      .bold, // 👈 NEGRILLA
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text: _formatearFecha(
                                                  factura.fechaEmision!,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      //Cambiar texto de la descripcion de la factura
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Estado: ',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight
                                                    .bold, // 👈 negrilla
                                                color: Colors.black,
                                              ),
                                            ),
                                            TextSpan(
                                              text: factura.estado
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _colorEstadoFactura(
                                                  factura.estado,
                                                ), // 🎨 color dinámico
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (factura.fechaVencimiento != null)
                                        Text(
                                          'Vence: ${_formatearFecha(factura.fechaVencimiento!)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: _getVencimientoColor(
                                              estadoVencimiento,
                                            ),
                                          ),
                                        ),

                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Total: ',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight
                                                    .bold, // 👈 NEGRILLA
                                                color: Colors.black,
                                              ),
                                            ),
                                            TextSpan(
                                              text: factura.total
                                                  .toStringAsFixed(2),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      /* Text(
                                      'Total: \$${factura.total.toStringAsFixed(2)}',style: const TextStyle(
                                                  fontWeight: FontWeight.bold, // 👈 AHORA SÍ SE VE
                                                ),
                                    ), */
                                      /*                                       Text(
                                        'Saldo: \$${factura.saldoPendiente.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: factura.saldoPendiente > 0
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                      ), */
                                    ],
                                  ),
                                  trailing: widget.modoAbonoMultiple
                                      ? null // No mostrar botón de pago en modo Abono
                                      : (factura.saldoPendiente > 0
                                            ? ElevatedButton.icon(
                                                onPressed: () {
                                                  debugPrint(
                                                    '🟣 [BOTÓN PAGAR] Presionado para factura #${factura.numeroFactura}',
                                                  );

                                                  try {
                                                    debugPrint(
                                                      '   → Obteniendo PagosService...',
                                                    );
                                                    final pagosService =
                                                        Provider.of<
                                                          PagosService
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    debugPrint(
                                                      '   ✓ PagosService obtenido: $pagosService',
                                                    );

                                                    debugPrint(
                                                      '   → Obteniendo FacturasService...',
                                                    );
                                                    final facturasService =
                                                        Provider.of<
                                                          FacturasService
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    debugPrint(
                                                      '   ✓ FacturasService obtenido: $facturasService',
                                                    );

                                                    debugPrint(
                                                      '   → Obteniendo AuthService...',
                                                    );
                                                    final authService =
                                                        Provider.of<
                                                          AuthService
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    debugPrint(
                                                      '   ✓ AuthService obtenido: $authService',
                                                    );
                                                    debugPrint(
                                                      '   ✓ Todos los Providers disponibles',
                                                    );

                                                    _showPagoDialog(
                                                      factura,
                                                      pagosService,
                                                      facturasService,
                                                      authService,
                                                    );
                                                  } catch (e) {
                                                    debugPrint(
                                                      '🔴 [ERROR] Excepción al obtener Providers',
                                                    );
                                                    debugPrint(
                                                      '   - Error: $e',
                                                    );
                                                    debugPrint(
                                                      '   - Tipo: ${e.runtimeType}',
                                                    );

                                                    CustomOverlayNotification.showError(
                                                      context,
                                                      'Error al obtener servicios: $e',
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.payment,
                                                  size: 16,
                                                ),
                                                label: const Text('Pagar'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color.fromRGBO(
                                                        11,
                                                        15,
                                                        24,
                                                        1,
                                                      ),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              )),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (totalPaginas > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, //Tamaño alto de paginacion
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      const Color(0xFF1A1C1E),
                                      const Color(0xFF252A35),
                                    ]
                                  : [Colors.grey.shade50, Colors.grey.shade100],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          //ESPACIO PARA LOS BOTONES DE PAGINACION
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 25,
                            runSpacing: 8,
                            children: [
                              // Botón anterior
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _paginaActual > 1
                                      ? LinearGradient(
                                          colors: isDark
                                              ? [
                                                  Colors.white12,
                                                  Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                                ]
                                              : [
                                                  Colors.black12,
                                                  Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                                ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(
                                            _paginaActual > 1 ? 0.2 : 0.05,
                                          )
                                        : Colors.black.withOpacity(
                                            _paginaActual > 1 ? 0.2 : 0.05,
                                          ),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _paginaActual > 1
                                      ? () => setState(() => _paginaActual--)
                                      : null,
                                  icon: Icon(
                                    Icons.chevron_left_rounded,
                                    color: _paginaActual > 1
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.white24
                                              : Colors.black26),
                                  ),
                                  tooltip: 'Página anterior',
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Indicador de página
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF2E3440),
                                            const Color(0xFF3B4252),
                                          ]
                                        : [Colors.white, Colors.grey.shade50],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.library_books_rounded,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$_paginaActual/$totalPaginas',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Botón siguiente
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _paginaActual < totalPaginas
                                      ? LinearGradient(
                                          colors: isDark
                                              ? [
                                                  Colors.white12,
                                                  Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                                ]
                                              : [
                                                  Colors.black12,
                                                  Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                                ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(
                                            _paginaActual < totalPaginas
                                                ? 0.2
                                                : 0.05,
                                          )
                                        : Colors.black.withOpacity(
                                            _paginaActual < totalPaginas
                                                ? 0.2
                                                : 0.05,
                                          ),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _paginaActual < totalPaginas
                                      ? () => setState(() => _paginaActual++)
                                      : null,
                                  icon: Icon(
                                    Icons.chevron_right_rounded,
                                    color: _paginaActual < totalPaginas
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.white24
                                              : Colors.black26),
                                  ),
                                  tooltip: 'Página siguiente',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'emitida':
        return Colors.orange;
      case 'pagada':
        return Colors.green;
      case 'anulada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  EstadoVencimiento _getEstadoVencimiento(Factura factura) {
    // Si ya está pagada o anulada, no mostrar alerta
    if (factura.estado.toLowerCase() == 'pagada' ||
        factura.estado.toLowerCase() == 'anulada') {
      return EstadoVencimiento.normal;
    }

    /*    // Si no tiene fecha de vencimiento o no tiene saldo pendiente
    if (factura.fechaVencimiento == null || factura.saldoPendiente <= 0) {
      return EstadoVencimiento.normal;
    } */

    final ahora = DateTime.now();
    final vencimiento = factura.fechaVencimiento!;
    final diferenciaDias = vencimiento.difference(ahora).inDays;

    if (diferenciaDias < 0) {
      return EstadoVencimiento.vencida;
    } else if (diferenciaDias <= 7) {
      return EstadoVencimiento.proximaVencer;
    } else {
      return EstadoVencimiento.normal;
    }
  }

  Color _getVencimientoColor(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.vencida:
        return Colors.red;
      case EstadoVencimiento.proximaVencer:
        return Colors.orange;
      case EstadoVencimiento.normal:
        return Colors.green;
    }
  }

  Color? _getCardColor(EstadoVencimiento estado) {
    switch (estado) {
      case EstadoVencimiento.vencida:
        return Colors.red.shade50;
      case EstadoVencimiento.proximaVencer:
        return Colors.orange.shade50;
      case EstadoVencimiento.normal:
        return null;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
