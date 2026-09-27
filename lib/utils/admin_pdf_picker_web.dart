// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'admin_pdf_picker_stub.dart';

Future<PickedAdminPdf?> pickAdminPdfFile() async {
  final completer = Completer<PickedAdminPdf?>();

  final input = html.FileUploadInputElement()
    ..accept = 'application/pdf,.pdf'
    ..multiple = false;

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(
          PickedAdminPdf(
            name: file.name,
            bytes: Uint8List.view(result),
          ),
        );
      } else if (result is Uint8List) {
        completer.complete(
          PickedAdminPdf(
            name: file.name,
            bytes: result,
          ),
        );
      } else {
        completer.complete(null);
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();

  return completer.future;
}
