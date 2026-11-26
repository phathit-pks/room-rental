// Supabase currently marks its WebAuthn ceremony APIs as experimental.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/http.dart' as http;
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_passkey_entry.dart';

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

Future<List<AdminPasskeyEntry>> listAdminPasskeys(GoTrueClient auth) async => [
  for (final key in await auth.passkey.list())
    (id: key.id, name: key.friendlyName ?? 'Passkey', createdAt: key.createdAt),
];

Future<AuthResponse> signInWithAdminPasskey(GoTrueClient auth) async {
  final assertion = await _requestAssertion(auth);
  return auth.passkey.verifyAuthentication(
    challengeId: assertion.challengeId,
    credential: assertion.credential,
  );
}

Future<void> deleteAdminPasskey(GoTrueClient auth, String passkeyId) async {
  final userId = auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('Sign in before deleting a passkey.');
  }

  final assertion = await _requestAssertion(
    auth,
    requireUserVerification: true,
  );
  final data = assertion.credential['response'] as Map;
  final authenticatorData = base64Url.decode(
    base64Url.normalize(data['authenticatorData'] as String),
  );
  // WebAuthn authenticator data byte 32 contains the signed user-verification bit.
  if (authenticatorData.length < 33 || (authenticatorData[32] & 0x04) == 0) {
    throw const AuthException(
      'User verification is required.',
      code: 'passkey_user_verification_required',
    );
  }

  // Verify the assertion without changing the session in this or other tabs.
  final response = await http
      .post(
        Uri.parse(
          '${SupabaseConfig.url}/auth/v1/passkeys/authentication/verify',
        ),
        headers: {
          'apikey': SupabaseConfig.publishableKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'challenge_id': assertion.challengeId,
          'credential': assertion.credential,
        }),
      )
      .timeout(const Duration(seconds: 15));
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw AuthException(
      'Passkey verification failed.',
      code: (body['error_code'] ?? body['code'])?.toString(),
      statusCode: response.statusCode.toString(),
    );
  }

  final verified = AuthResponse.fromJson(body);
  final temporarySession = verified.session;
  if (temporarySession == null) {
    throw const AuthException('Passkey verification did not yield a session.');
  }
  try {
    if (verified.user?.id != userId || auth.currentUser?.id != userId) {
      throw const AuthException(
        'The passkey belongs to another account.',
        code: 'passkey_account_mismatch',
      );
    }
    await auth.passkey.delete(passkeyId: passkeyId);
  } finally {
    try {
      await auth.admin
          .signOut(temporarySession.accessToken, scope: SignOutScope.local)
          .timeout(const Duration(seconds: 5));
    } on Exception {
      // This session was never persisted by the app.
    }
  }
}

Future<({String challengeId, Map<String, dynamic> credential})>
_requestAssertion(
  GoTrueClient auth, {
  bool requireUserVerification = false,
}) async {
  final credentials = _requireCredentials();
  final challenge = await auth.passkey.startAuthentication();
  final credential = await _getBrowserCredential(() {
    final publicKey = _parseRequestOptions(
      {
            ...challenge.options,
            if (requireUserVerification) 'userVerification': 'required',
          }.jsify()
          as JSObject,
    );
    return credentials.get(_CredentialOptions(publicKey: publicKey));
  });
  return (
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
    friendlyName: 'apphahong.com',
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
