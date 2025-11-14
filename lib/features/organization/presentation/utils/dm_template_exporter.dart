import 'dart:typed_data';

import 'dm_template_exporter_stub.dart'
    if (dart.library.html) 'dm_template_exporter_web.dart';

Future<void> downloadDmTemplatePng(Uint8List bytes, {required String fileName}) {
  return downloadDmTemplatePngImpl(bytes, fileName: fileName);
}

Future<void> printDmTemplate(Uint8List bytes, {required String fileName}) {
  return printDmTemplateImpl(bytes, fileName: fileName);
}


