import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Resize an image to 1080px width, encode as JPEG 85%, return base64 string.
  static Future<String> resizeForAI(String photoPath) async {
    final file = File(photoPath);
    final bytes = await file.readAsBytes();

    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception("Impossible de décoder l'image");
    }

    // Resize to 1080px width, maintaining aspect ratio
    final resized = img.copyResize(original, width: 1080);

    // Encode as JPEG with 85% quality
    final jpegBytes = img.encodeJpg(resized, quality: 85);

    // Convert to base64
    return base64Encode(jpegBytes);
  }
}
