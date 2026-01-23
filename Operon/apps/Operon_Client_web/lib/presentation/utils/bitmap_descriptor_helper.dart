import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class BitmapDescriptorHelper {
  BitmapDescriptorHelper._();

  /// Loads an asset image and returns PNG bytes resized to [targetWidth].
  ///
  /// This is useful for crisp map markers (avoids blurry scaling on-device/web).
  static Future<Uint8List> getBytesFromAsset(
    String path, {
    int targetWidth = 96,
  }) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

