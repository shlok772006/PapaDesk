import 'image_picker_stub.dart' if (dart.library.html) 'image_picker_web.dart' as picker;

Future<String?> pickImageAsBase64() async {
  return picker.pickBase64Image();
}
