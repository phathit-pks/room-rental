import 'package:supabase_flutter/supabase_flutter.dart';

bool get adminPasskeysSupported => false;

Future<bool> hasAdminPasskey(GoTrueClient auth) async => false;

Future<AuthResponse> signInWithAdminPasskey(GoTrueClient auth) async =>
    throw UnsupportedError('Passkeys are available in a supported browser.');

Future<void> registerAdminPasskey(GoTrueClient auth) async =>
    throw UnsupportedError('Passkeys are available in a supported browser.');
