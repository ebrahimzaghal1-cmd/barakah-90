import 'dart:typed_data';

Future<void> downloadPdfBytes(
  Uint8List bytes,
  String filename,
) async {
  throw UnsupportedError(
      'Direct browser PDF download is only available on web.');
}
