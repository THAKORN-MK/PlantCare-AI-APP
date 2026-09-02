import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../constants/plant_disease_reference.dart';
import '../models/plant_diagnosis.dart';
// TODO: Import your environment variable manager (e.g., flutter_dotenv)

class ApiService {
  static const String defaultModel = openRouterFreeModel;

  late final Dio _dio;

  final String _apiKey = openRouterApiKey;

  static String mimeTypeForPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.gif')) return 'image/gif';
    if (lowerPath.endsWith('.heic') || lowerPath.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  ApiService() {
    // Configure Dio once in the constructor
    _dio = Dio(
      BaseOptions(
        baseUrl: openRouterBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
          'X-Title': 'PlantCare AI',
        },
      ),
    );
  }

  Future<String> encodeImage(File image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  /// Generic method to handle OpenRouter POST requests and response parsing
  Future<String> _postToOpenRouter(Map<String, dynamic> data) async {
    try {
      if (_apiKey.isEmpty) {
        throw const HttpException(
          'ยังไม่ได้ตั้งค่า OPENROUTER_API_KEY สำหรับการวิเคราะห์ภาพ',
        );
      }

      final response = await _dio.post("/chat/completions", data: data);
      final jsonResponse = response.data;

      if (jsonResponse == null) {
        throw const HttpException('Empty response from OpenRouter');
      }

      if (jsonResponse['error'] != null) {
        throw HttpException(
          jsonResponse['error']['message']?.toString() ??
              'Unknown OpenRouter error',
        );
      }

      final choices = jsonResponse['choices'];
      if (choices == null || choices.isEmpty) {
        throw const HttpException('No response choices returned');
      }

      final content = choices[0]['message']?['content']?.toString();
      if (content == null || content.trim().isEmpty) {
        throw const HttpException('Empty AI response');
      }

      return content.trim();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message;
      debugPrint('DioException: $errorMsg');
      throw Exception('OpenRouter request failed: $errorMsg');
    } catch (e) {
      debugPrint('General Exception: $e');
      throw Exception('Error: $e');
    }
  }

  Future<String> sendDiseaseAdvice({
    required String diseaseName,
    String model = defaultModel,
  }) async {
    final prompt = '''
ช่วยแนะนำการดูแลพืชที่อาจเป็น "$diseaseName"

$plantDiseaseReferencePrompt

ตอบเป็นภาษาไทยเท่านั้น จำนวน 3 ข้อพอดี แต่ละข้อเป็นประโยคสั้นและขึ้นต้นด้วย "- "
เน้นการป้องกันและการดูแลที่ปลอดภัย ห้ามระบุอัตราผสมสารเคมีเฉพาะเจาะจง
หากกล่าวถึงสารป้องกันกำจัดโรค ให้แนะนำให้ทำตามฉลากและคำแนะนำของหน่วยงานเกษตรในพื้นที่
ห้ามแสดงขั้นตอนการคิด เหตุผลภายใน หรือคำว่า thinking process, analysis, input, task และ constraints
ห้ามใส่บทนำหรือคำอธิบายเพิ่มเติมนอกเหนือจาก 3 ข้อ
''';

    final data = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'max_tokens': 240,
    };

    final response = await _postToOpenRouter(data);
    return formatAdviceResponse(
      diseaseName: diseaseName,
      response: response,
    );
  }

  static String formatAdviceResponse({
    required String diseaseName,
    required String response,
  }) {
    final lowerResponse = response.toLowerCase();
    final looksLikeReasoning = lowerResponse.contains('thinking process') ||
        lowerResponse.contains('analyze user request') ||
        lowerResponse.contains('constraints') ||
        lowerResponse.contains('provide 3 tips') ||
        lowerResponse.contains('input:**') ||
        lowerResponse.contains('task:**');

    if (!looksLikeReasoning) {
      final thaiBullets = response
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => RegExp(r'^[-•]\s+').hasMatch(line))
          .map(
            (line) => '- ${line.replaceFirst(RegExp(r'^[-•]\s+'), '').trim()}',
          )
          .where(_hasThaiText)
          .take(3)
          .toList();

      if (thaiBullets.length == 3) {
        return thaiBullets.join('\n');
      }
    }

    return _fallbackAdvice(diseaseName);
  }

  static String _fallbackAdvice(String diseaseName) {
    final value = diseaseName.toLowerCase();
    if (value.contains('ราน้ำค้าง') || value.contains('downy mildew')) {
      return [
        '- นำใบที่มีอาการของโรคราน้ำค้างออกจากแปลงและทิ้งอย่างเหมาะสม',
        '- เว้นระยะต้นให้โปร่งและหลีกเลี่ยงการรดน้ำโดนใบโดยตรง',
        '- หากจำเป็นต้องใช้สารป้องกันโรค ให้ทำตามฉลากและคำแนะนำของหน่วยงานเกษตรในพื้นที่',
      ].join('\n');
    }
    if (value.contains('เน่าคอดิน') || value.contains('damping off')) {
      return [
        '- ถอนต้นกล้าที่โคนต้นเน่าออกทันทีเพื่อลดการแพร่กระจาย',
        '- ปรับการระบายน้ำและหลีกเลี่ยงการรดน้ำจนดินแฉะเกินไป',
        '- ใช้เมล็ดพันธุ์สะอาดและจัดระยะเพาะให้มีอากาศถ่ายเท',
      ].join('\n');
    }
    if (value.contains('ใบจุด') || value.contains('leaf spot')) {
      return [
        '- เก็บใบที่มีจุดหรือแผลออกจากบริเวณปลูกและไม่ทิ้งไว้บนดิน',
        '- หลีกเลี่ยงการให้น้ำกระเด็นโดนใบและรักษาทรงพุ่มให้โปร่ง',
        '- หากจำเป็นต้องใช้สารป้องกันโรค ให้ทำตามฉลากและคำแนะนำของหน่วยงานเกษตรในพื้นที่',
      ].join('\n');
    }
    if (value.contains('ราสนิมขาว') || value.contains('white rust')) {
      return [
        '- เด็ดใบที่มีอาการออกและกำจัดวัชพืชหรือเศษพืชที่อาจสะสมเชื้อ',
        '- ปรับพื้นที่ให้ระบายน้ำได้ดีและลดความชื้นสะสมรอบต้น',
        '- ปลูกพืชหมุนเวียนและใช้วิธีควบคุมตามคำแนะนำของหน่วยงานเกษตร',
      ].join('\n');
    }
    if (value.contains('โรคเหี่ยว') || value.contains('fusarium wilt')) {
      return [
        '- แยกและนำต้นที่เหี่ยวผิดปกติออกจากแปลงโดยระวังไม่ให้ดินกระจาย',
        '- ปรับการระบายน้ำและใช้ต้นกล้าที่แข็งแรงจากแหล่งที่เชื่อถือได้',
        '- ปลูกพืชหมุนเวียนและปฏิบัติตามคำแนะนำของหน่วยงานเกษตรในพื้นที่',
      ].join('\n');
    }
    return [
      '- แยกส่วนของพืชที่มีอาการออกและติดตามการเปลี่ยนแปลงอย่างใกล้ชิด',
      '- จัดให้พืชได้รับแสงและอากาศถ่ายเท พร้อมควบคุมการให้น้ำไม่ให้แฉะ',
      '- หากอาการลุกลาม ควรขอคำแนะนำจากหน่วยงานเกษตรในพื้นที่ก่อนรักษา',
    ].join('\n');
  }

  static bool _hasThaiText(String value) {
    return RegExp(r'[\u0E00-\u0E7F]').hasMatch(value);
  }

  Future<PlantDiagnosis> sendImageToOpenRouter({
    required File image,
    int maxTokens = 180,
    String model = defaultModel,
  }) async {
    final String base64Image = await encodeImage(image);
    final mimeType = mimeTypeForPath(image.path);

    const prompt = '''
วิเคราะห์ภาพพืชหรือใบไม้นี้เพื่อประเมินโรคหรือความผิดปกติที่เป็นไปได้

$plantDiseaseReferencePrompt

ตอบเป็น JSON ที่ถูกต้องเพียงวัตถุเดียว ห้ามใส่ markdown หรือข้อความอื่น โดยใช้คีย์ตามนี้:
{"disease_th":"ชื่อโรคภาษาไทย","disease_en":"ชื่อภาษาอังกฤษ","description_th":"คำอธิบายอาการจากภาพเป็นภาษาไทย 1-2 ประโยค"}

เลือกชื่อโรคที่ใกล้เคียงที่สุดจากข้อมูลอ้างอิงเมื่อมีหลักฐานพอ หากภาพไม่ชัด ไม่เห็นพืช หรือยืนยันโรคไม่ได้
ให้ใช้ disease_th เป็น "ไม่สามารถระบุโรคได้" และอธิบายเหตุผลสั้น ๆ เป็นภาษาไทย
''';

    final data = {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content':
              'คุณเป็นผู้ช่วยวิเคราะห์สุขภาพพืช ตอบตามรูปภาพอย่างระมัดระวังและไม่กล่าวอ้างเกินหลักฐาน',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': prompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'max_tokens': maxTokens,
      'temperature': 0.2,
    };

    final responseText = await _postToOpenRouter(data);
    return PlantDiagnosis.fromAiResponse(responseText);
  }

  Future<Map<String, String>> analyzePlantAndGetAdvice({
    required File image,
    String visionModel = defaultModel,
    String adviceModel = defaultModel,
  }) async {
    final diagnosis = await sendImageToOpenRouter(
      image: image,
      model: visionModel,
    );

    if (diagnosis.isUnknown) {
      return {
        'disease': diagnosis.displayName,
        'description': diagnosis.descriptionThai,
        'advice': '',
      };
    }

    final advice = await sendDiseaseAdvice(
      diseaseName: diagnosis.displayName,
      model: adviceModel,
    );

    return {
      'disease': diagnosis.displayName,
      'description': diagnosis.descriptionThai,
      'advice': advice,
    };
  }
}
