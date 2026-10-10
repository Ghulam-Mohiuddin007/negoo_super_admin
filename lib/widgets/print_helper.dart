import 'print_helper_stub.dart'
    if (dart.library.js_interop) 'print_helper_web.dart' as platform_printer;

void triggerPrint() {
  platform_printer.printDocument();
}
