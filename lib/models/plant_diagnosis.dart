import 'dart:convert';

/// Structured result returned by the plant-image analysis prompt.
class PlantDiagnosis {
  final String diseaseThai;
  final String diseaseEnglish;
  final String descriptionThai;

  const PlantDiagnosis({
    required this.diseaseThai,
    this.diseaseEnglish = '',
    required this.descriptionThai,
  });

  String get displayName {
    final thai = diseaseThai.trim();
    final english = diseaseEnglish.trim();
    if (english.isEmpty || english.toLowerCase() == thai.toLowerCase()) {
      return thai;
    }
    return '$thai ($english)';
  }

  bool get isUnknown {
    final value = diseaseThai.trim().toLowerCase();
    return value.isEmpty ||
        value.contains('ไม่สามารถระบุ') ||
        value.contains('ไม่ใช่ภาพพืช') ||
        value == "i don't know" ||
        value == 'please pick another image';
  }

  factory PlantDiagnosis.fromAiResponse(String response) {
    final raw = response.trim();
    if (raw.isEmpty) {
      return const PlantDiagnosis(
        diseaseThai: 'ไม่สามารถระบุโรคได้',
        descriptionThai: 'ไม่พบข้อมูลจากภาพนี้',
      );
    }

    final lowerRaw = raw.toLowerCase();
    if (lowerRaw.contains('please pick another image')) {
      return const PlantDiagnosis(
        diseaseThai: 'ไม่ใช่ภาพพืช',
        descriptionThai: 'กรุณาเลือกรูปใบไม้หรือต้นพืชที่เห็นรายละเอียดชัดเจน',
      );
    }
    if (lowerRaw.contains("i don't know") ||
        lowerRaw.contains('ไม่สามารถระบุ')) {
      return const PlantDiagnosis(
        diseaseThai: 'ไม่สามารถระบุโรคได้',
        descriptionThai: 'ภาพยังไม่ชัดหรือมีข้อมูลไม่เพียงพอสำหรับการวิเคราะห์',
      );
    }

    final jsonMap = _tryDecodeMap(raw);
    if (jsonMap != null) {
      return _fromMap(jsonMap);
    }

    // Keep the app useful if a free model ignores the JSON-only instruction.
    final thaiName = _thaiNameFor(raw);
    if (thaiName != null) {
      return PlantDiagnosis(
        diseaseThai: thaiName,
        diseaseEnglish: raw,
        descriptionThai: _defaultDescriptionFor(thaiName, raw) ??
            'ยังไม่มีคำอธิบายภาษาไทยจาก AI',
      );
    }
    if (_hasThaiText(raw)) {
      return PlantDiagnosis(
        diseaseThai: _cleanPlainText(raw),
        descriptionThai: 'ยังไม่มีคำอธิบายภาษาไทยจาก AI',
      );
    }

    return const PlantDiagnosis(
      diseaseThai: 'ไม่สามารถระบุโรคได้',
      descriptionThai: 'ภาพยังไม่ชัดหรือมีข้อมูลไม่เพียงพอสำหรับการวิเคราะห์',
    );
  }

  static PlantDiagnosis _fromMap(Map<String, dynamic> map) {
    final rawThai = _stringValue(
      map['disease_th'] ??
          map['diseaseThai'] ??
          map['thai_name'] ??
          map['disease'],
    );
    final english = _stringValue(
      map['disease_en'] ?? map['diseaseEnglish'] ?? map['english_name'],
    );
    final nestedEnglish = _tryDecodeMap(english);
    if (nestedEnglish != null &&
        (nestedEnglish.containsKey('disease_th') ||
            nestedEnglish.containsKey('diseaseThai') ||
            nestedEnglish.containsKey('description_th'))) {
      return _fromMap(nestedEnglish);
    }

    final description = _stringValue(
      map['description_th'] ??
          map['descriptionThai'] ??
          map['description'] ??
          map['symptoms_th'],
    );

    final safeEnglish = _looksLikeJson(english) ? '' : english;
    final safeDescription = _looksLikeJson(description) ? '' : description;
    final translatedThai = _thaiNameFor(rawThai) ?? _thaiNameFor(english);
    final diseaseThai =
        translatedThai ?? (_hasThaiText(rawThai) ? rawThai : '');
    final diseaseEnglish = safeEnglish.isNotEmpty
        ? safeEnglish
        : translatedThai != null && rawThai != diseaseThai
            ? rawThai
            : '';

    if (diseaseThai.isEmpty ||
        diseaseThai.toLowerCase().contains("i don't know") ||
        diseaseThai.toLowerCase().contains('unknown')) {
      return const PlantDiagnosis(
        diseaseThai: 'ไม่สามารถระบุโรคได้',
        descriptionThai: 'ภาพยังไม่ชัดหรือมีข้อมูลไม่เพียงพอสำหรับการวิเคราะห์',
      );
    }
    final thaiDescription = _hasThaiText(safeDescription)
        ? safeDescription
        : _defaultDescriptionFor(diseaseThai, diseaseEnglish) ??
            'ยังไม่มีคำอธิบายภาษาไทยจาก AI';

    return PlantDiagnosis(
      diseaseThai: diseaseThai,
      diseaseEnglish: diseaseEnglish,
      descriptionThai: thaiDescription,
    );
  }

  static String? _thaiNameFor(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.contains('โรคราน้ำค้าง') || normalized == 'downy mildew') {
      return 'โรคราน้ำค้าง';
    }
    if (normalized.contains('โรคเน่าคอดิน') ||
        normalized == 'damping off' ||
        normalized == 'damping-off') {
      return 'โรคเน่าคอดิน';
    }
    if (normalized.contains('โรคใบจุด') ||
        normalized == 'alternaria leaf spot' ||
        normalized == 'leaf spot') {
      return 'โรคใบจุด';
    }
    if (normalized.contains('โรคราสนิมขาว') || normalized == 'white rust') {
      return 'โรคราสนิมขาว';
    }
    if (normalized.contains('โรคเหี่ยว') ||
        normalized == 'fusarium wilt' ||
        normalized == 'wilt') {
      return 'โรคเหี่ยว';
    }
    return null;
  }

  static String? _defaultDescriptionFor(
    String diseaseThai,
    String diseaseEnglish,
  ) {
    final value = '$diseaseThai $diseaseEnglish'.toLowerCase();
    if (value.contains('ราน้ำค้าง') || value.contains('downy mildew')) {
      return 'มักพบปื้นเหลืองบนใบ และอาจมีผงสีขาวหรือเทาใต้ใบเมื่ออากาศชื้นและเย็น';
    }
    if (value.contains('เน่าคอดิน') || value.contains('damping off')) {
      return 'ต้นกล้าอาจโคนต้นเน่า ล้ม หรือยุบใกล้ผิวดิน โดยสัมพันธ์กับน้ำขังและอากาศถ่ายเทไม่ดี';
    }
    if (value.contains('ใบจุด') || value.contains('leaf spot')) {
      return 'ใบมีจุดหรือแผลสีน้ำตาลถึงดำ บางแผลอาจเป็นวงซ้อนและทำให้เนื้อเยื่อรอบข้างเหลือง';
    }
    if (value.contains('ราสนิมขาว') || value.contains('white rust')) {
      return 'ด้านบนใบอาจมีจุดเหลือง และด้านใต้ใบอาจพบตุ่มนูนสีขาวในสภาพชื้นแฉะ';
    }
    if (value.contains('โรคเหี่ยว') || value.contains('fusarium wilt')) {
      return 'ใบล่างอาจเหลืองและเหี่ยวลามขึ้นด้านบน และอาจพบวงสีน้ำตาลในท่อลำเลียง';
    }
    return null;
  }

  static bool _hasThaiText(String value) {
    return RegExp(r'[\u0E00-\u0E7F]').hasMatch(value);
  }

  static bool _looksLikeJson(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('{') && trimmed.endsWith('}');
  }

  static Map<String, dynamic>? _tryDecodeMap(String raw) {
    var candidate = raw;
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      candidate = candidate.substring(start, end + 1);
    }

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static String _stringValue(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static String _cleanPlainText(String value) => value.trim();
}
