// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadDmTemplatePngImpl(
  Uint8List bytes, {
  required String fileName,
}) async {
  final blob = html.Blob(<dynamic>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> printDmTemplateImpl(
  Uint8List bytes, {
  required String fileName,
}) async {
  final blob = html.Blob(<dynamic>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final html.WindowBase? popup = html.window.open('', '_blank');
  if (popup == null) {
    html.Url.revokeObjectUrl(url);
    throw Exception('Unable to open print preview. Please allow pop-ups.');
  }

  if (popup is! html.Window) {
    html.Url.revokeObjectUrl(url);
    throw Exception('Unsupported window context for printing.');
  }

  final html.Window window = popup;
  final doc = window.document;
  if (doc is! html.HtmlDocument) {
    html.Url.revokeObjectUrl(url);
    throw Exception('Unable to build print document.');
  }

  final html.HtmlDocument htmlDoc = doc;
  htmlDoc.title = fileName;

  html.BodyElement body;
  if (htmlDoc.body == null) {
    body = html.BodyElement();
    htmlDoc.append(body);
  } else {
    body = htmlDoc.body!;
    body.children.clear();
  }

  body.style
    ..margin = '0'
    ..backgroundColor = '#ffffff'
    ..display = 'flex'
    ..justifyContent = 'center'
    ..alignItems = 'center'
    ..width = '100vw'
    ..height = '100vh';

  final img = html.ImageElement(src: url)
    ..id = 'dm-print-image'
    ..style.maxWidth = '100%'
    ..style.maxHeight = '100%';

  img.onLoad.listen((_) {
    window.print();
    html.Url.revokeObjectUrl(url);
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(url);
  });

  body.append(img);

  if (img.complete == true) {
    window.print();
    html.Url.revokeObjectUrl(url);
  }
}

