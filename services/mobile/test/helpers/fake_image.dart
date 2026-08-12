import 'dart:convert';
import 'dart:io';

/// A minimal valid 1x1 transparent PNG, used so widgets that decode a real
/// photo file (FileImage) in tests get bytes an image codec can actually
/// decode, instead of flaking on a fabricated/empty file.
const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Future<String> writeFakePhoto() async {
  final dir = await Directory.systemTemp.createTemp('revenue_agent_app_test_');
  final file = File('${dir.path}/seller_photo.png');
  await file.writeAsBytes(base64Decode(_onePixelPngBase64));
  return file.path;
}
