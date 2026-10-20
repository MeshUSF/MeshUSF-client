import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class BrowserDetection {
  static bool get isChrome {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('chrome');
  }

  static bool get supportsWebBluetooth {
    return web.window.navigator.getProperty<JSAny?>('bluetooth'.toJS) != null;
  }
}