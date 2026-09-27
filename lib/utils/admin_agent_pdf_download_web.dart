// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadAdminAgentPdf(
  Uint8List bytes,
  String filename,
) async {
  final blob = html.Blob(
    <Object>[bytes],
    'application/pdf',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(anchor);

  try {
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
