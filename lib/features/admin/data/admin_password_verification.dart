import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> verifyAdminPassword(User user, String password) async {
  final email = user.email;
  if (email == null) {
    throw const AuthException(
      'This account has no email for password verification.',
      code: 'admin_reauth_unavailable',
    );
  }

  // Exchange the password without replacing or persisting the active session.
  final response = await http
      .post(
        Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
        headers: {
          'apikey': SupabaseConfig.publishableKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw AuthException(
      'Password verification failed.',
      code: switch (response.statusCode) {
        400 || 401 || 403 => 'admin_reauth_failed',
        429 => 'admin_reauth_rate_limited',
        _ => 'admin_reauth_unavailable',
      },
    );
  }

  final result = AuthResponse.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
  final temporarySession = result.session;
  if (temporarySession != null) {
    try {
      await Supabase.instance.client.auth.admin
          .signOut(temporarySession.accessToken, scope: SignOutScope.local)
          .timeout(const Duration(seconds: 5));
    } on Exception {
      // The temporary session was never stored or used by the app.
    }
  }
  if (temporarySession == null || result.user?.id != user.id) {
    throw const AuthException(
      'The verification did not match the Admin account.',
      code: 'admin_reauth_failed',
    );
  }
}
