import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../../models/enums.dart';

class SyncedUser {
  const SyncedUser({
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String email;
  final String fullName;
  final UserRole role;
}

class UserSyncService {
  UserSyncService._();

  static const List<String> _cloudFunctionRegions = [
    'europe-west1',
    'us-central1',
  ];
  static const List<String> _callableFunctionNames = [
    'syncUserToPostgresV1',
    'syncUserToPostgres',
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

  static List<String> get _functionRegions {
    if (_useFunctionsEmulator) {
      return const ['europe-west1'];
    }
    return _cloudFunctionRegions;
  }

  static Future<SyncedUser> syncSignedInUser({
    String? preferredFullName,
    UserRole? preferredRole,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'Aktif kullanici bulunamadi.',
      );
    }

    final fullName = _buildFullName(
      preferredFullName: preferredFullName,
      fallbackDisplayName: user.displayName,
      fallbackEmail: user.email,
    );

    final tokenRole = await _readRoleFromIdToken(user);
    final requestedRole = preferredRole ?? tokenRole;
    final localFallbackRole = requestedRole;

    Map<String, dynamic> buildPayload({bool includeRole = true}) => {
      'fullName': fullName,
      if (includeRole && requestedRole != null) 'role': requestedRole.value,
      if (_useFunctionsEmulator) '__emulatorUid': user.uid,
      if (_useFunctionsEmulator && (user.email ?? '').trim().isNotEmpty)
        '__emulatorEmail': user.email!.trim(),
    };

    dynamic responseData;
    FirebaseFunctionsException? functionError;

    try {
      responseData = await _callSyncFunction(buildPayload());
    } on FirebaseFunctionsException catch (error) {
      functionError = error;
    }

    // Some backends reject explicit privileged role payloads on login.
    // Retry without role once and let backend resolve the persisted role.
    if (functionError != null &&
        preferredRole == null &&
        requestedRole != null &&
        functionError.code == 'permission-denied') {
      try {
        responseData = await _callSyncFunction(
          buildPayload(includeRole: false),
        );
        functionError = null;
      } on FirebaseFunctionsException catch (retryError) {
        functionError = retryError;
      }
    }

    if (functionError != null) {
      if (localFallbackRole == null) {
        throw functionError;
      }

      return SyncedUser(
        email: user.email ?? '',
        fullName: fullName,
        role: localFallbackRole,
      );
    }

    final responseMap = _toMap(responseData);
    final syncedRole = _resolveRole(
      responseMap['role'] as String?,
      preferredRole: localFallbackRole,
    );
    final syncedEmail = _nonEmptyOrFallback(
      responseMap['email'] as String?,
      fallback: user.email ?? '',
    );
    final syncedFullName = _nonEmptyOrFallback(
      responseMap['fullName'] as String?,
      fallback: fullName,
    );

    return SyncedUser(
      email: syncedEmail,
      fullName: syncedFullName,
      role: syncedRole,
    );
  }

  static Future<dynamic> _callSyncFunction(Map<String, dynamic> payload) async {
    FirebaseFunctionsException? notFoundError;
    FirebaseFunctionsException? emulatorUnavailableError;

    for (final region in _functionRegions) {
      if (_useFunctionsEmulator) {
        for (final emulatorHost in _resolveFunctionsEmulatorHosts()) {
          try {
            return await _callSyncFunctionForRegion(
              region,
              payload,
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
        return await _callSyncFunctionForRegion(region, payload);
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

  static Future<dynamic> _callSyncFunctionForRegion(
    String region,
    Map<String, dynamic> payload, {
    String? emulatorHost,
  }) async {
    FirebaseFunctionsException? lastError;
    for (var i = 0; i < _callableFunctionNames.length; i++) {
      final functionName = _callableFunctionNames[i];
      final isLastFunction = i == _callableFunctionNames.length - 1;
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

      // Retry once after forcing token refresh to avoid auth race on startup.
      await user.getIdToken(true);
      final retryResponse = await callable.call(payload);
      return retryResponse.data;
    }
  }

  static String _buildFullName({
    String? preferredFullName,
    String? fallbackDisplayName,
    String? fallbackEmail,
  }) {
    final preferred = preferredFullName?.trim() ?? '';
    if (preferred.isNotEmpty) {
      return preferred;
    }

    final displayName = fallbackDisplayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = fallbackEmail?.trim() ?? '';
    if (email.contains('@')) {
      final prefix = email.split('@').first.replaceAll('.', ' ').trim();
      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return 'Yeni Kullanici';
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

  static UserRole _resolveRole(String? rawRole, {UserRole? preferredRole}) {
    return _parseRole(rawRole) ?? preferredRole ?? UserRole.normalUser;
  }

  static Future<UserRole?> _readRoleFromIdToken(User user) async {
    Map<String, dynamic>? claims;
    try {
      claims = (await user.getIdTokenResult(true)).claims;
    } on FirebaseAuthException {
      claims = (await user.getIdTokenResult()).claims;
    }
    if (claims == null || claims.isEmpty) {
      return null;
    }

    final roleValueCandidates = [
      claims['role'],
      claims['user_role'],
      claims['userRole'],
      claims['app_role'],
      claims['appRole'],
    ];
    for (final value in roleValueCandidates) {
      if (value is String) {
        final parsedRole = _parseRole(value);
        if (parsedRole != null) {
          return parsedRole;
        }
      }
    }

    final adminFlags = [claims['isAdmin'], claims['admin'], claims['is_admin']];
    if (adminFlags.any((value) => value == true)) {
      return UserRole.admin;
    }

    final companyOfficerFlags = [
      claims['isCompanyOfficer'],
      claims['companyOfficer'],
      claims['company_officer'],
      claims['is_company_officer'],
      claims['firmaYetkilisi'],
      claims['firma_yetkilisi'],
      claims['firmaGorevlisi'],
      claims['firma_gorevlisi'],
    ];
    if (companyOfficerFlags.any((value) => value == true)) {
      return UserRole.companyOfficer;
    }

    final normalUserFlags = [
      claims['isUser'],
      claims['is_user'],
      claims['user'],
      claims['normalUser'],
      claims['normal_user'],
    ];
    if (normalUserFlags.any((value) => value == true)) {
      return UserRole.normalUser;
    }

    return null;
  }

  static String _nonEmptyOrFallback(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback;
  }

  static UserRole? _parseRole(String? roleValue) {
    final normalized = (roleValue ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'normal_user':
      case 'normal-user':
      case 'normal user':
      case 'normaluser':
      case 'user':
        return UserRole.normalUser;
      case 'company_officer':
      case 'company-officer':
      case 'company officer':
      case 'companyofficer':
      case 'company':
      case 'firma_gorevlisi':
      case 'firma gorevlisi':
      case 'firma_yetkilisi':
      case 'firma yetkilisi':
        return UserRole.companyOfficer;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      default:
        return null;
    }
  }
}
