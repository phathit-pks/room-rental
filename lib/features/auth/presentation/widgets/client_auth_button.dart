import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:room_rental/core/public_language.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/shared/widgets/app_dialog.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';

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
      return OutlinedButton(
        onPressed: null,
        child: Text(context.publicText('เข้าสู่ระบบ', 'ເຂົ້າລະບົບ')),
      );
    }
    final activeAuth = auth;
    return StreamBuilder<AuthState>(
      stream: activeAuth.onAuthStateChange,
      builder: (context, _) {
        final user = activeAuth.currentUser;
        if (user == null) {
          return OutlinedButton(
            onPressed: () => _showSignIn(context),
            child: Text(context.publicText('เข้าสู่ระบบ', 'ເຂົ້າລະບົບ')),
          );
        }
        final metadata = user.userMetadata ?? const <String, dynamic>{};
        final name = (metadata['full_name'] ?? metadata['name'] ?? user.email)
            ?.toString();
        final avatar = metadata['avatar_url']?.toString();
        return PopupMenuButton<String>(
          tooltip: context.publicText('บัญชีของฉัน', 'ບັນຊີຂອງຂ້ອຍ'),
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
                      name ?? context.publicText('ผู้ใช้งาน', 'ຜູ້ໃຊ້'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (user.email != null)
                      Text(user.email!, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sign_out',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: Text(context.publicText('ออกจากระบบ', 'ອອກຈາກລະບົບ')),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.borderStrong),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: context.colors.primaryContainer,
                  backgroundImage: avatar == null ? null : NetworkImage(avatar),
                  child: avatar == null
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    name ?? context.publicText('บัญชีของฉัน', 'ບັນຊີຂອງຂ້ອຍ'),
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppDialog(
      title: const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 126, height: 40, child: AppLogo()),
      ),
      scrollable: true,
      content: SizedBox(
        width: 352,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'เข้าสู่ระบบหรือสมัครสมาชิก',
                style: text.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ใช้บัญชี Google เพื่อบันทึกห้องที่ชอบและใช้บริการสำหรับสมาชิก',
              style: text.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _loading ? null : _signIn,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF1A73E8),
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              label: Text(
                _loading ? 'กำลังเชื่อมต่อ…' : 'ดำเนินการต่อด้วย Google',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: colors.danger),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'การดำเนินการต่อหมายถึงคุณยอมรับนโยบายการใช้งานของเว็บไซต์',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
