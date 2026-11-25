// Supabase currently marks its WebAuthn ceremony APIs as experimental.
// ignore_for_file: experimental_member_use

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('isSecureContext')
external bool get _isSecureContext;

@JS('navigator.credentials')
external _Credentials? get _credentials;

@JS('PublicKeyCredential.parseCreationOptionsFromJSON')
external JSObject _parseCreationOptions(JSObject options);

@JS('PublicKeyCredential.parseRequestOptionsFromJSON')
external JSObject _parseRequestOptions(JSObject options);

extension type _Credentials(JSObject _) implements JSObject {
  external JSPromise<_PublicKeyCredential?> create(_CredentialOptions options);
  external JSPromise<_PublicKeyCredential?> get(_CredentialOptions options);
}

extension type _CredentialOptions._(JSObject _) implements JSObject {
  external _CredentialOptions({required JSObject publicKey});
}

extension type _PublicKeyCredential(JSObject _) implements JSObject {
  external JSObject toJSON();
}

bool get adminPasskeysSupported {
  if (!_isSecureContext || _credentials == null) return false;
  final api = globalContext.getProperty<JSObject?>('PublicKeyCredential'.toJS);
  return api != null &&
      api.has('parseCreationOptionsFromJSON') &&
      api.has('parseRequestOptionsFromJSON') &&
      api.getProperty<JSObject>('prototype'.toJS).has('toJSON');
}

Future<bool> hasAdminPasskey(GoTrueClient auth) async =>
    (await auth.passkey.list()).isNotEmpty;

Future<AuthResponse> signInWithAdminPasskey(GoTrueClient auth) async {
  final credentials = _requireCredentials();
  final challenge = await auth.passkey.startAuthentication();
  final credential = await _getBrowserCredential(() {
    final publicKey = _parseRequestOptions(
      challenge.options.jsify() as JSObject,
    );
    return credentials.get(_CredentialOptions(publicKey: publicKey));
  });
  return auth.passkey.verifyAuthentication(
    challengeId: challenge.challengeId,
    credential: _serialize(credential),
  );
}

Future<void> registerAdminPasskey(GoTrueClient auth) async {
  final credentials = _requireCredentials();
  final userId = auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('Sign in before registering a passkey.');
  }

  final challenge = await auth.passkey.startRegistration(
    friendlyName: 'HaHong.la',
  );
  final credential = await _getBrowserCredential(() {
    final publicKey = _parseCreationOptions(
      challenge.options.jsify() as JSObject,
    );
    return credentials.create(_CredentialOptions(publicKey: publicKey));
  });
  if (auth.currentUser?.id != userId) {
    throw const AuthException('Account changed during passkey registration.');
  }
  await auth.passkey.verifyRegistration(
    challengeId: challenge.challengeId,
    credential: _serialize(credential),
  );
}

Future<_PublicKeyCredential?> _getBrowserCredential(
  JSPromise<_PublicKeyCredential?> Function() request,
) async {
  try {
    return await request().toDart;
  } catch (error) {
    // The browser rejects the Promise with a DOMException, not a Supabase error.
    final description = error.toString();
    final name = RegExp(
      r'NotAllowedError|AbortError|SecurityError|InvalidStateError|NotSupportedError|ConstraintError|EncodingError',
    ).firstMatch(description)?.group(0);
    throw AuthException(
      'Browser declined the WebAuthn request.',
      code: name == null ? 'browser_passkey_error' : 'browser_$name',
    );
  }
}

_Credentials _requireCredentials() {
  if (!adminPasskeysSupported) {
    throw UnsupportedError('Passkeys are available in a supported browser.');
  }
  return _credentials!;
}

Map<String, dynamic> _serialize(_PublicKeyCredential? credential) {
  if (credential == null) {
    throw const AuthException(
      'Passkey request cancelled.',
      code: 'browser_NotAllowedError',
    );
  }
  return Map<String, dynamic>.from(credential.toJSON().dartify() as Map);
}
