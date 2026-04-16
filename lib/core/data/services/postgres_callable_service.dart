import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PostgresCallableService {
  PostgresCallableService._();

  static const List<String> _cloudFunctionRegions = [
    'europe-west1',
    'us-central1',
  ];
  static final bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: kDebugMode,
  );
  static const String _functionsEmulatorHostFromDefine = String.fromEnvironment(
    'FUNCTIONS_EMULATOR_HOST',
    defaultValue: '',
  );
  static const int _functionsEmulatorPort = int.fromEnvironment(
    'FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );

  static Future<Map<String, dynamic>> call({
    required String functionName,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{...(data ?? const <String, dynamic>{})};
    final user = FirebaseAuth.instance.currentUser;

    if (_useFunctionsEmulator && user != null) {
      payload['__emulatorUid'] = user.uid;
      final email = user.email?.trim() ?? '';
      if (email.isNotEmpty) {
        payload['__emulatorEmail'] = email;
      }
    }

    final responseData = await _callFunction(
      functionNames: ['${functionName}V1', functionName],
      payload: payload,
    );
    return _toMap(responseData);
  }

  static Future<dynamic> _callFunction({
    required List<String> functionNames,
    required Map<String, dynamic> payload,
  }) async {
    FirebaseFunctionsException? notFoundError;
    FirebaseFunctionsException? emulatorUnavailableError;

    for (final region in _functionRegions) {
      if (_useFunctionsEmulator) {
        for (final emulatorHost in _resolveFunctionsEmulatorHosts()) {
          try {
            return await _callFunctionForRegion(
              region: region,
              functionNames: functionNames,
              payload: payload,
              emulatorHost: emulatorHost,
            );
          } on FirebaseFunctionsException catch (error) {
            if (error.code == 'not-found') {
              notFoundError = error;
              break;
            }
            if (error.code == 'unavailable' ||
                error.code == 'deadline-exceeded') {
              emulatorUnavailableError = error;
              continue;
            }
            rethrow;
          }
        }
        continue;
      }

      try {
        return await _callFunctionForRegion(
          region: region,
          functionNames: functionNames,
          payload: payload,
        );
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'not-found') {
          notFoundError = error;
          continue;
        }
        rethrow;
      }
    }

    if (notFoundError != null) {
      throw notFoundError;
    }
    if (emulatorUnavailableError != null) {
      throw emulatorUnavailableError;
    }

    throw StateError('Callable function region list is empty.');
  }

  static Future<dynamic> _callFunctionForRegion({
    required String region,
    required List<String> functionNames,
    required Map<String, dynamic> payload,
    String? emulatorHost,
  }) async {
    FirebaseFunctionsException? lastError;

    for (var i = 0; i < functionNames.length; i++) {
      final functionName = functionNames[i];
      final isLastFunction = i == functionNames.length - 1;
      final callable = _functionsInstanceForRegion(
        region,
        emulatorHost: emulatorHost,
      ).httpsCallable(functionName);

      try {
        final response = await _callCallableWithAuthRetry(
          callable: callable,
          payload: payload,
        );
        return response;
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        final shouldTryNextFunction =
            !isLastFunction &&
            (error.code == 'not-found' || error.code == 'permission-denied');
        if (shouldTryNextFunction) {
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw StateError('Callable function list is empty.');
  }

  static FirebaseFunctions _functionsInstanceForRegion(
    String region, {
    String? emulatorHost,
  }) {
    final instance = FirebaseFunctions.instanceFor(region: region);
    if (_useFunctionsEmulator) {
      instance.useFunctionsEmulator(
        emulatorHost ?? _resolveFunctionsEmulatorHosts().first,
        _functionsEmulatorPort,
      );
    }
    return instance;
  }

  static Future<dynamic> _callCallableWithAuthRetry({
    required HttpsCallable callable,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await callable.call(payload);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unauthenticated') {
        rethrow;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        rethrow;
      }

      await user.getIdToken(true);
      final retryResponse = await callable.call(payload);
      return retryResponse.data;
    }
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    return <String, dynamic>{};
  }

  static List<String> get _functionRegions {
    if (_useFunctionsEmulator) {
      return const ['europe-west1'];
    }
    return _cloudFunctionRegions;
  }

  static List<String> _resolveFunctionsEmulatorHosts() {
    final hosts = <String>[];
    final unique = <String>{};

    void addHost(String host) {
      final normalized = host.trim();
      if (normalized.isEmpty) {
        return;
      }
      if (unique.add(normalized)) {
        hosts.add(normalized);
      }
    }

    final hostFromDefine = _functionsEmulatorHostFromDefine.trim();
    if (hostFromDefine.isNotEmpty) {
      final candidates = hostFromDefine.split(RegExp(r'[,;\s]+'));
      for (final candidate in candidates) {
        addHost(candidate);
      }
    }

    if (kIsWeb) {
      addHost('localhost');
      addHost('127.0.0.1');
      return hosts;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        addHost('10.0.2.2');
        addHost('127.0.0.1');
        addHost('localhost');
        return hosts;
      case TargetPlatform.iOS:
        addHost('127.0.0.1');
        addHost('localhost');
        return hosts;
      default:
        addHost('localhost');
        addHost('127.0.0.1');
        return hosts;
    }
  }
}
