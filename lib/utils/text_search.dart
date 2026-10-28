import 'package:pinyin_pro_flutter/pinyin_pro_flutter.dart';

/// Whether [query] matches any of [fields].
///
/// Matching ignores case, spaces and punctuation, accepts full pinyin or
/// pinyin initials ("gaodengshuxue" / "gdsx" for "高等数学"), and falls back to
/// an in-order match so a split keyword such as "高数" still finds it.
bool matchesSearch(String query, Iterable<String> fields) {
  final needle = _normalize(query);
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if (_searchable(field).matches(needle)) return true;
  }
  return false;
}

/// Pinyin conversion is cached: the same course names are matched on every
/// keystroke while the user types.
final _cache = <String, _Searchable>{};

_Searchable _searchable(String text) => _cache[text] ??= _Searchable(text);

class _Searchable {
  _Searchable(String text) : _text = _normalize(text) {
    // Codes and Latin names need no pinyin, and skipping them keeps the first
    // keystroke cheap on long lists.
    if (!_han.hasMatch(text)) return;
    final syllables = _syllables(text);
    _pinyin = syllables.join();
    _initials = syllables.map(_firstChar).join();
  }

  final String _text;
  String _pinyin = '';
  String _initials = '';

  bool matches(String needle) {
    for (final haystack in [_text, _pinyin, _initials]) {
      if (haystack.isEmpty) continue;
      if (haystack.contains(needle)) return true;
      // A single character is already covered by contains(); requiring two
      // keeps the in-order fallback from matching almost every entry.
      if (needle.length > 1 && _isSubsequence(needle, haystack)) return true;
    }
    return false;
  }
}

final _han = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');

/// Tone-free syllables, polyphonic characters resolved by phrase, e.g.
/// "重庆" -> ["chong", "qing"] rather than ["zhong", "qing"].
List<String> _syllables(String text) {
  try {
    // The package declares a dynamic return because it can also emit a list.
    final reading =
        pinyin(text, options: const PinyinOptions(toneType: ToneType.none))
            as String;
    return reading.split(' ').where((part) => part.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

String _firstChar(String value) => value.substring(0, 1);

final _ignored = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

String _normalize(String value) =>
    value.toLowerCase().replaceAll(_ignored, '');

bool _isSubsequence(String needle, String haystack) {
  var index = 0;
  for (var i = 0; i < haystack.length && index < needle.length; i++) {
    if (haystack.codeUnitAt(i) == needle.codeUnitAt(index)) index++;
  }
  return index == needle.length;
}
