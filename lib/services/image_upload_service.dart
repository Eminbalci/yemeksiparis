import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  /// Uploads an image file to Catbox.moe (completely free, anonymous, and keyless).
  /// Returns the direct public HTTP URL of the uploaded image.
  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse('https://catbox.moe/user/api.php');
      final request = http.MultipartRequest('POST', url);

      // Catbox required fields
      request.fields['reqtype'] = 'fileupload';

      // Read image bytes and add multipart attachment
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'fileToUpload',
        bytes,
        filename: imageFile.name,
      );
      request.files.add(multipartFile);

      // Send post request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        // On success, Catbox returns the direct file URL (e.g. https://files.catbox.moe/xxxxxx.png)
        if (responseText.startsWith('http')) {
          debugPrint('Image uploaded successfully: $responseText');
          return responseText;
        }
      }
      debugPrint('ImageUploadService upload failed with status: ${response.statusCode}, body: ${response.body}');
    } catch (e) {
      debugPrint('ImageUploadService Error: $e');
    }
    return null;
  }
}
