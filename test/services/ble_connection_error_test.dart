import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/services/ble_connection_error.dart';

void main() {
  group('Bluetooth connection guidance', () {
    test('identifies Android Nearby Devices permission failures', () {
      for (final text in [
        'Need android.permission.BLUETOOTH_CONNECT permission',
        'BLUETOOTH_SCAN permission missing',
        'Permission denied',
        'Permission not granted',
      ]) {
        expect(classifyBleConnectionError(text), BleConnectionError.permission);
      }
    });

    test('pairing failures do not imply that the PIN was definitely wrong', () {
      for (final text in [
        'org.bluez.Error.AuthenticationFailed',
        'Authentication failed',
        'org.bluez.Error.AuthenticationRejected',
        'org.bluez.Error.AuthenticationCanceled',
        'NotPermitted: not paired',
        'Linux BLE pairing did not complete',
        'Linux BLE trust repair did not complete',
        'Pairing fallback failed',
        'Timed out waiting for bond',
      ]) {
        expect(classifyBleConnectionError(text), BleConnectionError.pairing);
      }
    });

    test('distinguishes adapter-off errors', () {
      for (final text in [
        'Bluetooth is off',
        'Bluetooth adapter is off',
        'adapter is not on',
      ]) {
        expect(
          classifyBleConnectionError(text),
          BleConnectionError.bluetoothOff,
        );
      }
    });

    test('generic timeout is not diagnosed as a pairing failure', () {
      expect(
        classifyBleConnectionError(TimeoutException('Connecting')),
        BleConnectionError.timeout,
      );
      expect(
        classifyBleConnectionError('connect timed out after 15s'),
        BleConnectionError.timeout,
      );
    });

    test('unknown GATT errors keep the existing fallback', () {
      for (final text in ['', 'GATT_ERROR 133', 'Disconnected', 'Bad state']) {
        expect(classifyBleConnectionError(text), BleConnectionError.unknown);
      }
    });
  });
}
