import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image from the gallery, resizes/compresses it to keep the base64 payload small,
/// and returns it formatted as a Data URL (data:image/jpeg;base64,...).
/// Works out-of-the-box on Web (Chrome) and Mobile (Android/iOS).
Future<String?> pickImageAsBase64() async {
  try {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,      // Constrain size to 200px to keep the base64 payload extremely light (~3-5KB)
      maxHeight: 200,     // Constrain height
      imageQuality: 60,   // High compression (thumbnail size)
    );
    
    if (image == null) return null;
    
    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);
    
    // Mime-type detection based on file extension
    final ext = image.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  } catch (e) {
    debugPrint('Error picking image: $e');
    return null;
  }
}
