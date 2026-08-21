import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showClientSignInDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _GoogleSignInDialog(),
);

class ClientAuthButton extends StatelessWidget {
  const ClientAuthButton({super.key});

  @override
  Widget build(BuildContext context) {
    GoTrueClient? auth;
    try {
      auth = Supabase.instance.client.auth;
    } catch (_) {
      // Widget tests may render the app without initializing Supabase.
    }
    if (auth == null) {
      return const OutlinedButton(onPressed: null, child: Text('เข้าสู่ระบบ'));
    }
    final activeAuth = auth;
    return StreamBuilder<AuthState>(
      stream: activeAuth.onAuthStateChange,
      builder: (context, _) {
        final user = activeAuth.currentUser;
        if (user == null) {
          return OutlinedButton(
            onPressed: () => _showSignIn(context),
            child: const Text('เข้าสู่ระบบ'),
          );
        }
        final metadata = user.userMetadata ?? const <String, dynamic>{};
        final name = (metadata['full_name'] ?? metadata['name'] ?? user.email)
            ?.toString();
        final avatar = metadata['avatar_url']?.toString();
        return PopupMenuButton<String>(
          tooltip: 'บัญชีของฉัน',
          onSelected: (value) async {
            if (value == 'sign_out') await activeAuth.signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: SizedBox(
                width: 230,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'ผู้ใช้งาน',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (user.email != null)
                      Text(user.email!, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'sign_out',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout),
                title: Text('ออกจากระบบ'),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFE0E7FF),
                  backgroundImage: avatar == null ? null : NetworkImage(avatar),
                  child: avatar == null
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    name ?? 'บัญชีของฉัน',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSignIn(BuildContext context) async {
    await showClientSignInDialog(context);
  }
}

class _GoogleSignInDialog extends StatefulWidget {
  const _GoogleSignInDialog();

  @override
  State<_GoogleSignInDialog> createState() => _GoogleSignInDialogState();
}

class _GoogleSignInDialogState extends State<_GoogleSignInDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/',
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'เข้าสู่ระบบไม่สำเร็จ: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_add_alt_1_outlined, size: 30),
    ),
    title: const Text('เข้าสู่ระบบหรือสมัครสมาชิก'),
    content: SizedBox(
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ใช้บัญชี Google เพื่อบันทึกรายการโปรดและใช้งานบริการสำหรับสมาชิก',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _signIn,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ดำเนินการต่อด้วย Google'),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'การดำเนินการต่อหมายถึงคุณยอมรับนโยบายการใช้งานของเว็บไซต์',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
}
