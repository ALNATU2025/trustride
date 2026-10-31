import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a profile photo and returns it as a small base64 JPEG.
///
/// Photos are resized to 320 px and compressed (~20–40 KB) and stored on the
/// user's Firestore document, so no Firebase Storage (paid plan) is needed.
class PhotoService {
  static final _picker = ImagePicker();

  /// Returns null if the user cancelled.
  static Future<String?> pick({bool camera = false}) async {
    final file = await _picker.pickImage(
      source: camera && !kIsWeb ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 600 * 1024) {
      throw Exception('That photo is too large. Please choose another one.');
    }
    return base64Encode(bytes);
  }

  static Uint8List? decode(String b64) {
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
