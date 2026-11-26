import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_passkey_entry.dart';

bool get adminPasskeysSupported => false;

Future<List<AdminPasskeyEntry>> listAdminPasskeys(GoTrueClient auth) async =>
    const [];

Future<void> deleteAdminPasskey(GoTrueClient auth, String passkeyId) async =>
    throw UnsupportedError('Passkeys are available in a supported browser.');

Future<AuthResponse> signInWithAdminPasskey(GoTrueClient auth) async =>
    throw UnsupportedError('Passkeys are available in a supported browser.');

Future<void> registerAdminPasskey(GoTrueClient auth) async =>
    throw UnsupportedError('Passkeys are available in a supported browser.');
