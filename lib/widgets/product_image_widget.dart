import 'dart:convert';
import 'package:flutter/material.dart';

/// Renders a product image from Base64 or falls back to a clean placeholder icon.
Widget buildProductImage(String? imageBase64, {double size = 48}) {
  if (imageBase64 == null || imageBase64.isEmpty) {
    return _fallbackIcon(size);
  }
  
  try {
    if (imageBase64.startsWith('data:image')) {
      final commaIndex = imageBase64.indexOf(',');
      if (commaIndex != -1) {
        final base64Data = imageBase64.substring(commaIndex + 1);
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallbackIcon(size),
          ),
        );
      }
    }
  } catch (_) {}
  
  return _fallbackIcon(size);
}

Widget _fallbackIcon(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.shopping_bag_outlined,
      color: Colors.blue[700],
      size: size * 0.55,
    ),
  );
}
