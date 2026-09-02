import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/models/plant_diagnosis.dart';

void main() {
  test('parses a Thai plant diagnosis response', () {
    const response = '''
{"disease_th":"โรคราน้ำค้าง","disease_en":"Downy mildew","description_th":"พบปื้นเหลืองบนใบและเชื้อราสีขาวใต้ใบ"}
''';

    final diagnosis = PlantDiagnosis.fromAiResponse(response);

    expect(diagnosis.diseaseThai, 'โรคราน้ำค้าง');
    expect(diagnosis.diseaseEnglish, 'Downy mildew');
    expect(
      diagnosis.descriptionThai,
      'พบปื้นเหลืองบนใบและเชื้อราสีขาวใต้ใบ',
    );
    expect(diagnosis.displayName, 'โรคราน้ำค้าง (Downy mildew)');
  });

  test('parses JSON wrapped in a markdown code fence', () {
    final diagnosis = PlantDiagnosis.fromAiResponse('''
```json
{"disease_th":"โรคใบจุด","disease_en":"Alternaria leaf spot","description_th":"พบแผลสีน้ำตาลบนใบ"}
```
''');

    expect(diagnosis.diseaseThai, 'โรคใบจุด');
    expect(diagnosis.diseaseEnglish, 'Alternaria leaf spot');
  });

  test('uses a Thai fallback when the model returns a known English disease',
      () {
    final diagnosis = PlantDiagnosis.fromAiResponse('''
{"disease_en":"Downy mildew","description_th":"พบปื้นเหลืองบนใบ"}
''');

    expect(diagnosis.diseaseThai, 'โรคราน้ำค้าง');
    expect(diagnosis.diseaseEnglish, 'Downy mildew');
    expect(diagnosis.isUnknown, isFalse);
  });

  test('does not present an unknown English label as a Thai disease name', () {
    final diagnosis = PlantDiagnosis.fromAiResponse('''
{"disease_en":"Some unknown plant condition","description_th":"ไม่พบลักษณะที่ยืนยันได้"}
''');

    expect(diagnosis.isUnknown, isTrue);
    expect(diagnosis.diseaseThai, 'ไม่สามารถระบุโรคได้');
  });

  test('unwraps a diagnosis JSON accidentally nested in disease_en', () {
    final diagnosis = PlantDiagnosis.fromAiResponse(r'''
{"disease_th":"โรคราน้ำค้าง","disease_en":"{\"disease_th\":\"โรคราน้ำค้าง\",\"disease_en\":\"Downy mildew\",\"description_th\":\"พบปื้นเหลืองบนใบ\"}","description_th":""}
''');

    expect(diagnosis.diseaseThai, 'โรคราน้ำค้าง');
    expect(diagnosis.diseaseEnglish, 'Downy mildew');
    expect(diagnosis.descriptionThai, 'พบปื้นเหลืองบนใบ');
  });
}
