import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/facturas_service.dart';
import '../../../core/services/navigation_service.dart';
import '../../../models/factura.dart';
import '../../facturas/screens/factura_detalle_screen.dart';

class HistorialMovimientosScreen extends StatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  State<HistorialMovimientosScreen> createState() =>
      _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState extends State<HistorialMovimientosScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  int _paginaActual = 1;
  final int _facturasPorPagina = 10;

  // 🏷️ Filtro de fecha para facturas
  DateTime? _fechaInicioFacturas;
  DateTime? _fechaFinFacturas;

  // 🏷️ Filtro de fecha para pagos
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void dispose() {
    _tabController.dispose();
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
    // Suscribir al RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  // RouteAware callbacks
  @override
  void didPush() {
    // Pantalla fue abierta -> refrescar datos
    if (mounted) {
      _refrescarDatos();
      debugPrint(
        '🟢 [DIDPUSH-HISTORIAL] Pantalla abierta, refrescando datos...',
      );
    }
  }

  @override
  void didPopNext() {
    // Volvió a esta pantalla desde otra -> refrescar
    if (mounted) {
      debugPrint(
        '🟡 [DIDPOPNEXT-HISTORIAL] Volviendo a historial, refrescando datos...',
      );
      _refrescarDatos();
    }
  }

  // 🏷️ Refrescar datos de historial
  void _refrescarDatos() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final facturasService = Provider.of<FacturasService>(
      context,
      listen: false,
    );

    if (authService.clienteActual == null) return;

    // Recargar facturas
    facturasService.fetchFacturas(
      clienteId: authService.clienteActual?.id,
      esAdmin: authService.esInstalador,
    );
  }

  // 🏷️ Seleccionar rango de fechas para facturas
  Future<void> _seleccionarRangoFechasFacturas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _fechaInicioFacturas != null && _fechaFinFacturas != null
          ? DateTimeRange(start: _fechaInicioFacturas!, end: _fechaFinFacturas!)
          : null,
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      setState(() {
        _fechaInicioFacturas = picked.start;
        _fechaFinFacturas = picked.end;
      });
    }
  }

  // 🏷️ Limpiar filtro de fechas para facturas
  void _limpiarFiltroFechasFacturas() {
    setState(() {
      _fechaInicioFacturas = null;
      _fechaFinFacturas = null;
    });
  }

  // 🏷️ Seleccionar rango de fechas para pagos
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
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
    }
  }

  // 🏷️ Limpiar filtro de fechas
  void _limpiarFiltroFechas() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🔹 PASO 5: resetear paginación al volver a Facturas
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() {
          _paginaActual = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final facturasService = Provider.of<FacturasService>(context);

    if (!authService.estaLogueado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de Movimientos')),
        body: const Center(child: Text('Debes estar logueado')),
      );
    }

    // Obtener todas las facturas ordenadas por fecha descendente
    final facturasOrdenadas = List<Factura>.from(facturasService.facturas);
    facturasOrdenadas.sort((a, b) {
      final fechaA = a.fechaEmision ?? DateTime(1980);
      final fechaB = b.fechaEmision ?? DateTime(1980);
      return fechaB.compareTo(fechaA);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Facturas'),
            Tab(text: 'Pagos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Facturas
          facturasOrdenadas.isEmpty
              ? const Center(child: Text('No hay facturas'))
              : _buildFacturasTab(facturasOrdenadas),
          // Tab 2: Pagos
          _buildPagosTab(),
        ],
      ),
    );
  }

  Widget _buildFacturasTab(List<Factura> facturas) {
    // 🔹 FILTRO DE FECHA: aplicar filtrado antes de paginar
    List<Factura> facturasFiltradasPorFecha = facturas;
    if (_fechaInicioFacturas != null && _fechaFinFacturas != null) {
      facturasFiltradasPorFecha = facturas.where((factura) {
        final fecha = factura.fechaEmision ?? DateTime.now();
        return fecha.isAfter(_fechaInicioFacturas!) &&
            fecha.isBefore(_fechaFinFacturas!.add(const Duration(days: 1)));
      }).toList();
    }

    // 🔹 PASO 2: lógica de paginación (AQUÍ)
    final totalFacturas = facturasFiltradasPorFecha.length;
    final totalPaginas = (totalFacturas / _facturasPorPagina).ceil();

    final startIndex = (_paginaActual - 1) * _facturasPorPagina;
    final endIndex = (startIndex + _facturasPorPagina).clamp(0, totalFacturas);

    final facturasPaginadas = startIndex < totalFacturas
        ? facturasFiltradasPorFecha.sublist(startIndex, endIndex)
        : <Factura>[];

    // 🔹 AHORA sí puedes usar facturasPaginadas
    return Column(
      children: [
        // 🏷️ Filtro de fecha
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _seleccionarRangoFechasFacturas,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _fechaInicioFacturas == null
                        ? 'Filtrar por fecha'
                        : '${DateFormat('dd/MM').format(_fechaInicioFacturas!)} - ${DateFormat('dd/MM').format(_fechaFinFacturas!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (_fechaInicioFacturas != null) ...[const SizedBox(width: 8)],
              if (_fechaInicioFacturas != null)
                OutlinedButton.icon(
                  onPressed: _limpiarFiltroFechasFacturas,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: facturasPaginadas.length,
            itemBuilder: (context, index) {
              final factura = facturasPaginadas[index];

              Color estadoColor = Colors.orange;
              if (factura.estado.toLowerCase() == 'pagada') {
                estadoColor = Colors.green;
              } else if (factura.estado.toLowerCase() == 'anulada') {
                estadoColor = Colors.grey;
              }

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
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Factura #${factura.numeroFactura}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: estadoColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                factura.estado.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: estadoColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Creada: ${_formatearFecha(factura.fechaEmision ?? DateTime.now())}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ✅ EL IF VA AQUÍ, DENTRO DE children
        if (totalPaginas > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _paginaActual > 1
                      ? () {
                          setState(() {
                            _paginaActual--;
                          });
                        }
                      : null,
                ),
                Text(
                  'Página $_paginaActual de $totalPaginas',
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _paginaActual < totalPaginas
                      ? () {
                          setState(() {
                            _paginaActual++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPagosTab() {
    // 🏷️ Por ahora, mostrar mensaje indicando que el historial de pagos
    // se cargará cuando tengamos el endpoint de pagos
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Historial de Pagos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí se mostrarán todos los pagos registrados con fecha y hora.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            // 🏷️ Filtro de fecha
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _seleccionarRangoFechas,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _fechaInicio == null
                      ? 'Filtrar por fecha'
                      : '${DateFormat('dd/MM').format(_fechaInicio!)} - ${DateFormat('dd/MM').format(_fechaFin!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (_fechaInicio != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _limpiarFiltroFechas,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text(
                  'Limpiar filtro',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
