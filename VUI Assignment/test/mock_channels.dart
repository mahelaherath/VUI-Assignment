import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupMockChannels() {
  // Initialize FFI database factory for unit/widget testing on Dart VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (MethodCall methodCall) async {
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'checkPermissionStatus') {
        return 1; // PermissionStatus.granted
      }
      if (methodCall.method == 'requestPermission') {
        return {1: 1}; // PermissionStatus.granted
      }
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'initialize') {
        return true;
      }
      if (methodCall.method == 'has_permission') {
        return true;
      }
      // Return true for stop, cancel, listen, etc., to avoid unhandled async behavior
      return true;
    },
  );
}
