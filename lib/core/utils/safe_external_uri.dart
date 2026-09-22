final class SafeExternalUri {
  const SafeExternalUri._();

  static Uri? https(String? value) {
    final input = value?.trim();
    if (input == null || input.isEmpty || input.length > 2048) return null;
    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri;
  }

  static Uri? telephone(String? value) {
    final input = value?.trim();
    if (input == null || input.isEmpty || input.length > 32) return null;
    if (!RegExp(r'^\+?[0-9 ()-]{5,32}$').hasMatch(input)) return null;
    final normalized = input.replaceAll(RegExp(r'[ ()-]'), '');
    return Uri(scheme: 'tel', path: normalized);
  }
}
