import 'dart:async';
import 'dart:js' as js;

Object? getProperty(Object? object, Object property) {
  if (object == null) return null;
  final jsObj = js.JsObject.fromBrowserObject(object);
  return jsObj[property as String];
}

Object? callMethod(Object? object, String method, List<Object?> args) {
  if (object == null) return null;
  final jsObj = js.JsObject.fromBrowserObject(object);
  return jsObj.callMethod(method, args);
}

Future<T> promiseToFuture<T>(Object promise) {
  final completer = Completer<T>();
  final jsPromise = js.JsObject.fromBrowserObject(promise);
  jsPromise.callMethod('then', [
    (value) {
      completer.complete(value as T);
    },
    (error) {
      completer.completeError(error);
    },
  ]);
  return completer.future;
}
