import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'facturas_service.dart';
import 'package:provider/provider.dart';
import 'navigation_service.dart';
import 'package:flutter/material.dart';
import '../../screens/payment_receipt_screen.dart';

class FirebaseMessagingService {
  FirebaseMessaging? _messaging;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Singleton pattern
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  /// 🚀 INICIALIZACIÓN AL ARRANCAR LA APP
  /// Solo obtiene y guarda el token localmente
  /// NO lo registra en el backend hasta que el usuario haga login
  Future<void> initialize() async {
    // Evitar inicializar si Firebase no está inicializado o la plataforma no
    // es compatible (ej. Windows sin opciones configuradas).
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (kDebugMode) {
        print('⚠️ Firebase Messaging omitido en Windows');
      }
      return;
    }

    // Asegurarnos de que Firebase está inicializado
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Firebase no inicializado, omitiendo FirebaseMessaging');
      }
      return;
    }

    // Inicializar instancia
    _messaging = FirebaseMessaging.instance;

    // Inicializar notificaciones locales
    await _initializeLocalNotifications();

    // Solicitar permisos
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('✅ Permisos de notificación concedidos');
      }

      // ⚡ IMPORTANTE: Solo obtener y guardar el token
      // NO lo registramos en el backend aquí
      String? token = await getToken();
      if (token != null) {
        if (kDebugMode) {
          print('📱 Token FCM obtenido: ${token.substring(0, 20)}...');
          print('⏳ Token NO registrado en backend (esperando login)');
        }
      }

      // Configurar handlers
      _setupMessageHandlers();
    } else {
      if (kDebugMode) {
        print('⚠️ Permisos de notificación denegados');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('👆 Usuario tocó la notificación local: ${response.payload}');
        }
      },
    );

    // Crear canal de notificaciones para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Notificaciones Importantes', // nombre
      description: 'Canal para notificaciones de alta prioridad',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// 🔑 REGISTRAR TOKEN EN BACKEND AL HACER LOGIN
  /// Este método se llama SOLO cuando el usuario inicia sesión
  /// El token se guarda UNA SOLA VEZ por dispositivo
  Future<void> registrarTokenEnBackend() async {
    try {
      // Obtener token guardado localmente
      String? token = await getToken();
      if (token == null) {
        if (kDebugMode) {
          print('⚠️ No hay token FCM disponible');
        }
        return;
      }

      // Verificar que haya usuario logueado
      final clienteId = await _apiService.getClienteId();
      if (clienteId == null) {
        if (kDebugMode) {
          print('⚠️ No hay cliente logueado, no se puede registrar token');
        }
        return;
      }

      if (kDebugMode) {
        print('🔄 Registrando token en backend para cliente $clienteId...');
      }

      // Llamar al endpoint del backend para registrar el token
      await _apiService.registrarTokenFCM(
        token,
        dispositivo: 'Cliente_$clienteId',
      );

      if (kDebugMode) {
        print('✅ Token registrado exitosamente en backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al registrar token: $e');
      }
    }
  }

  void _setupMessageHandlers() {
    // Cuando la app está en foreground
    if (_messaging == null) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📨 Notificación recibida (foreground):');
        print('   Título: ${message.notification?.title}');
        print('   Cuerpo: ${message.notification?.body}');
      }

      // ✅ MOSTRAR NOTIFICACIÓN LOCAL CUANDO LA APP ESTÁ ABIERTA
      _mostrarNotificacionLocal(message);

      // Si la notificación es de tipo 'pago', mostrar pantalla del comprobante
      try {
        final data = message.data ?? {};
        if (data['tipo'] == 'pago') {
          // Notificar a FacturasService para que recargue vistas
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null) {
            try {
              final facturasService = Provider.of<FacturasService>(
                ctx,
                listen: false,
              );
              facturasService.notifyUpdated();
            } catch (_) {}

            // Navegar a la pantalla del comprobante después del build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                // Preparar datos del comprobante
                final paymentData = {
                  'numeroFactura': data['numeroFactura'] ?? 'INV-0000',
                  'numeroPago': data['numeroPago'] ?? 'PAG-0000',
                  'monto':
                      double.tryParse(data['monto']?.toString() ?? '0.0') ??
                      0.0,
                  'metodoPago': data['metodoPago'] ?? 'tarjeta',
                  'fechaPago':
                      data['fechaPago'] ?? DateTime.now().toIso8601String(),
                  'nombreProducto': data['nombreProducto'] ?? 'Servicio',
                  'rucCliente': data['rucCliente'] ?? 'N/A',
                  'nombreCliente': data['nombreCliente'] ?? 'Cliente',
                  'estado': 'completado',
                };

                // Navegar a la pantalla del comprobante
                Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentReceiptScreen(paymentData: paymentData),
                  ),
                );
              }
            });
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error manejando notificación: $e');
      }
    });

    // Cuando el usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('👆 Usuario tocó la notificación');
      }
    });
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'Notificaciones Importantes',
          channelDescription: 'Canal para notificaciones de alta prioridad',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nueva notificación',
      message.notification?.body ?? '',
      platformDetails,
      payload: message.data.toString(),
    );
  }

  // Para manejar notificaciones cuando la app está completamente cerrada
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('📨 Notificación en background: ${message.notification?.title}');
    }
  }

  Future<String?> getToken() async {
    try {
      // Evitar llamar a getToken en Windows si el plugin no implementa la plataforma
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (kDebugMode) {
          print('⚠️ getToken no está implementado en Windows para este plugin');
        }
        return null;
      }

      // Si _messaging no fue inicializado, retornamos null
      if (_messaging == null) return null;

      // Agregamos explícitamente null para el vapidKey si no lo usas
      return await _messaging!.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener token: $e');
      }
      return null;
    }
  }
}
