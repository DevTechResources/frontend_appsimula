import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class PaymentReceiptService {
  /// Captura un widget como imagen
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      return pngBytes;
    } catch (e) {
      debugPrint('❌ Error al capturar widget: $e');
      return null;
    }
  }

  /// Guarda la imagen en el almacenamiento del dispositivo
  static Future<bool> saveImage(Uint8List imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'comprobante_pago_$timestamp.png';
      final filepath = '${directory.path}/$filename';

      final file = File(filepath);
      await file.writeAsBytes(imageBytes);

      debugPrint('✅ Imagen guardada en: $filepath');
      return true;
    } catch (e) {
      debugPrint('❌ Error al guardar imagen: $e');
      return false;
    }
  }

  /// Comparte la imagen usando la aplicación de compartir del sistema
  static Future<bool> shareImage(
    Uint8List imageBytes,
    String subject, {
    String? text,
  }) async {
    try {
      // Guardar temporalmente
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'comprobante_pago_$timestamp.png';
      final filepath = '${directory.path}/$filename';

      final file = File(filepath);
      await file.writeAsBytes(imageBytes);

      // Compartir
      await Share.shareXFiles([XFile(filepath)], subject: subject, text: text);

      debugPrint('✅ Imagen compartida correctamente');
      return true;
    } catch (e) {
      debugPrint('❌ Error al compartir imagen: $e');
      return false;
    }
  }

  /// Guarda la imagen en la galería del dispositivo
  static Future<bool> saveToGallery(Uint8List imageBytes) async {
    try {
      final hasPermission = await _ensureGalleryPermission();
      if (!hasPermission) {
        debugPrint('❌ Permiso denegado para guardar en galería');
        return false;
      }

      // Guardar temporalmente el archivo
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'comprobante_pago_$timestamp.png';
      final filepath = '${directory.path}/$filename';

      final file = File(filepath);
      await file.writeAsBytes(imageBytes);

      // Guardar en galería usando gal
      await Gal.putImage(filepath, album: 'Tech Resources');

      debugPrint('✅ Imagen guardada en galería');
      return true;
    } catch (e) {
      debugPrint('❌ Error al guardar en galería: $e');
      return false;
    }
  }

  static Future<bool> _ensureGalleryPermission() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted;
    }

    if (Platform.isIOS) {
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted || photosStatus.isLimited;
    }

    return true;
  }

  /// Retorna los bytes de imagen (sin redimensionamiento necesario)
  /// Ya viene optimizada con pixelRatio: 3.0 en captureWidget
  static Uint8List processImage(Uint8List imageBytes) {
    return imageBytes;
  }
}
