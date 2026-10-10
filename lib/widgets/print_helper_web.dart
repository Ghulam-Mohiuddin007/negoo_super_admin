import 'dart:js_interop';

@JS('window')
external JSWindow get _window;

@JS()
extension type JSWindow(JSObject _) implements JSObject {
  external void print();
}

void printDocument() {
  try {
    _window.print();
  } catch (_) {}
}
