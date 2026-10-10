import 'dart:js_interop';

@JS('window.print')
external void _print();

void printDocument() {
  try {
    _print();
  } catch (_) {}
}
