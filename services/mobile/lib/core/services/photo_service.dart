import 'package:image_picker/image_picker.dart';

class PhotoService {
  final ImagePicker _picker;

  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<String?> captureFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    return file?.path;
  }
}
