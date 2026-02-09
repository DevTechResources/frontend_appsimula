import 'package:flutter/widgets.dart';

/// Key global para obtener contexto desde servicios (p. ej. manejadores de FCM)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// RouteObserver global para escuchar cambios de ruta (p. ej. saber cuando
/// una pantalla es visible otra vez). Suscribirse con `routeObserver.subscribe(...)`.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
