import 'dart:typed_data';

class PickedAdminPdf {
  final String name;
  final Uint8List bytes;

  const PickedAdminPdf({
    required this.name,
    required this.bytes,
  });
}

Future<PickedAdminPdf?> pickAdminPdfFile() async {
  return null;
}
