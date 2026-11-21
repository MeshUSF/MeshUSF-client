/// Presentation-only categories. These must not drive pairing or retry policy.
enum BleConnectionError { permission, pairing, bluetoothOff, timeout, unknown }

BleConnectionError classifyBleConnectionError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('bluetooth_scan') ||
      text.contains('bluetooth_connect') ||
      text.contains('permission denied') ||
      text.contains('permission not granted')) {
    return BleConnectionError.permission;
  }
  if (text.contains('authenticationfailed') ||
      text.contains('authentication failed') ||
      text.contains('authenticationrejected') ||
      text.contains('authenticationcanceled') ||
      text.contains('notpermitted: not paired') ||
      text.contains('linux ble pairing did not complete') ||
      text.contains('linux ble trust repair did not complete') ||
      text.contains('pairing fallback failed') ||
      ((text.contains('pair') || text.contains('bond')) &&
          text.contains('timed out'))) {
    return BleConnectionError.pairing;
  }
  if (text.contains('bluetooth is off') ||
      text.contains('bluetooth adapter is off') ||
      text.contains('adapter is not on')) {
    return BleConnectionError.bluetoothOff;
  }
  if (text.contains('timeoutexception') || text.contains('timed out')) {
    return BleConnectionError.timeout;
  }
  return BleConnectionError.unknown;
}
