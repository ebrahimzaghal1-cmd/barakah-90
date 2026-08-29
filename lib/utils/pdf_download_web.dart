import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadPdfBytes(
  Uint8List bytes,
  String filename,
) async {
  final parts = <JSAny>[
    bytes.toJS,
  ].toJS;

  final blob = web.Blob(
    parts,
    web.BlobPropertyBag(type: 'application/pdf'),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}
