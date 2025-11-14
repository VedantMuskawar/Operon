import 'dart:typed_data';

Future<void> downloadDmTemplatePngImpl(
  Uint8List bytes, {
  required String fileName,
}) async {
  throw UnsupportedError(
    'Template export is only supported on web at the moment.',
  );
}

Future<void> printDmTemplateImpl(
  Uint8List bytes, {
  required String fileName,
}) async {
  throw UnsupportedError(
    'Template printing is only supported on web at the moment.',
  );
}


