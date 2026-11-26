import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:room_rental/core/utils/lao_thai_transliteration.dart';

enum PublicLanguage { thai, lao }

class PublicLanguageScope extends InheritedWidget {
  const PublicLanguageScope({
    required this.language,
    required super.child,
    super.key,
  });

  final PublicLanguage language;

  static PublicLanguage of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PublicLanguageScope>()
          ?.language ??
      PublicLanguage.thai;

  @override
  bool updateShouldNotify(PublicLanguageScope oldWidget) =>
      language != oldWidget.language;
}

extension PublicLanguageText on BuildContext {
  bool get usesLao => PublicLanguageScope.of(this) == PublicLanguage.lao;

  String publicDataLabel(String value) =>
      kIsWeb && !usesLao ? transliterateLaoToThai(value) : value;

  String publicText(String thai, String lao) => usesLao ? lao : thai;
}
