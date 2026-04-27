import 'dart:convert';

String repairTextEncoding(String value) {
  if (value.isEmpty || !_looksLikeCyrillicMojibake(value)) {
    return value;
  }

  final candidate = _decodeCp1251Mojibake(value);
  if (candidate == null || candidate == value) {
    return value;
  }

  return _repairScore(candidate) > _repairScore(value) ? candidate : value;
}

List<String> repairTextListEncoding(List<String> values) {
  return values.map(repairTextEncoding).toList();
}

String? _decodeCp1251Mojibake(String value) {
  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune <= 0x7f) {
      bytes.add(rune);
      continue;
    }

    final byte = _cp1251ByteByRune[rune];
    if (byte == null) {
      return null;
    }
    bytes.add(byte);
  }

  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return null;
  }
}

bool _looksLikeCyrillicMojibake(String value) {
  return RegExp(
    r'[РС][\u0400-\u045f\u2018-\u201e\u2020\u2021\u2026\u2030\u2039\u203a\u20ac\u2116\u2122\u00a0-\u00bf]',
  ).hasMatch(value);
}

int _repairScore(String value) {
  final cyrillic = RegExp(r'[А-Яа-яЁё]').allMatches(value).length;
  final mojibakePairs = RegExp(
    r'[РС][\u0400-\u045f\u2018-\u201e\u2020\u2021\u2026\u2030\u2039\u203a\u20ac\u2116\u2122\u00a0-\u00bf]',
  ).allMatches(value).length;
  final replacementChars = '�'.allMatches(value).length;

  return cyrillic * 4 - mojibakePairs * 9 - replacementChars * 20;
}

final Map<int, int> _cp1251ByteByRune = _buildCp1251ReverseMap();

Map<int, int> _buildCp1251ReverseMap() {
  final map = <int, int>{};
  for (var byte = 0; byte <= 0x7f; byte++) {
    map[byte] = byte;
  }

  const upper = [
    0x0402,
    0x0403,
    0x201a,
    0x0453,
    0x201e,
    0x2026,
    0x2020,
    0x2021,
    0x20ac,
    0x2030,
    0x0409,
    0x2039,
    0x040a,
    0x040c,
    0x040b,
    0x040f,
    0x0452,
    0x2018,
    0x2019,
    0x201c,
    0x201d,
    0x2022,
    0x2013,
    0x2014,
    0x0098,
    0x2122,
    0x0459,
    0x203a,
    0x045a,
    0x045c,
    0x045b,
    0x045f,
    0x00a0,
    0x040e,
    0x045e,
    0x0408,
    0x00a4,
    0x0490,
    0x00a6,
    0x00a7,
    0x0401,
    0x00a9,
    0x0404,
    0x00ab,
    0x00ac,
    0x00ad,
    0x00ae,
    0x0407,
    0x00b0,
    0x00b1,
    0x0406,
    0x0456,
    0x0491,
    0x00b5,
    0x00b6,
    0x00b7,
    0x0451,
    0x2116,
    0x0454,
    0x00bb,
    0x0458,
    0x0405,
    0x0455,
    0x0457,
  ];

  for (var index = 0; index < upper.length; index++) {
    map[upper[index]] = 0x80 + index;
  }
  for (var byte = 0xc0; byte <= 0xdf; byte++) {
    map[0x0410 + byte - 0xc0] = byte;
  }
  for (var byte = 0xe0; byte <= 0xff; byte++) {
    map[0x0430 + byte - 0xe0] = byte;
  }

  return map;
}
