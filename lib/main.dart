import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';
import 'core/services/carrito_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/facturas_service.dart';
import 'core/services/pagos_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/productos_service.dart';
import 'core/services/favoritos_service.dart';
import 'core/services/datos_facturacion_service.dart';
import 'core/services/direcciones_envio_service.dart';
import 'features/datos_facturacion/screens/datos_facturacion_screen.dart';
import 'features/direcciones_envio/screens/direcciones_envio_screen.dart';
import 'theme/app_theme.dart';
import 'core/services/navigation_service.dart';
import 'features/cuenta/screens/mi_cuenta_screen.dart';
import 'core/logs/app_logger.dart';

// ✅ Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Notificación en background: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Inicializar logger profesional
  await AppLogger.initialize();
  AppLogger.logInfo('=== Iniciando aplicación TechStore ===');

  // Inicializar Firebase solo en plataformas soportadas por `DefaultFirebaseOptions`
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado correctamente');
    AppLogger.logInfo('Firebase inicializado correctamente');

    // ✅ Configurar handler para notificaciones en background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ Inicializar servicio de notificaciones
    await FirebaseMessagingService().initialize();
  } else {
    print('⚠️ Firebase omitido en plataforma: $defaultTargetPlatform');
    AppLogger.logWarning(
      'Firebase omitido en plataforma: $defaultTargetPlatform',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ProductosService()),
        ChangeNotifierProvider(create: (context) => CarritoService()),
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => FacturasService()),
        ChangeNotifierProvider(
          create: (context) => PagosService(context.read<AuthService>()),
        ),
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(create: (context) => FavoritosService()),
        ChangeNotifierProvider(create: (context) => DatosFacturacionService()),
        ChangeNotifierProvider(create: (context) => DireccionesEnvioService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [routeObserver],
          title: 'TechStore - Tienda en Línea',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          // Configuración de localización en español
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'), // Español
            Locale('en', 'US'), // Inglés (fallback)
          ],
          locale: const Locale('es', 'ES'),
          home: const MainScreen(),
          routes: {
            '/datos-facturacion': (context) => const DatosFacturacionScreen(),
            '/direcciones-envio': (context) => const DireccionesEnvioScreen(),
            '/mi-cuenta': (context) => const MiCuentaScreen(), // ✅ NUEVA
          },
        );
      },
    );
  }
}
