import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantcare_ai/constants/constants.dart';
import 'package:plantcare_ai/constants/plant_disease_reference.dart';
import 'package:plantcare_ai/models/plant_diagnosis.dart';
import 'package:plantcare_ai/screens/history_page.dart';

import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  PlantDiagnosis? _diagnosis;
  String diseasePrecautions = '';

  bool detecting = false;
  bool precautionLoading = false;
  bool isSaving = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _diagnosis = null;
          diseasePrecautions = '';
        });
      }
    } catch (error) {
      if (mounted) _showErrorSnackBar(error);
    }
  }

  Future<void> detectDisease() async {
    final image = _selectedImage;
    if (image == null || detecting) return;

    setState(() {
      detecting = true;
      _diagnosis = null;
      diseasePrecautions = '';
    });
    try {
      final result = await apiService.sendImageToOpenRouter(image: image);
      if (!mounted) return;
      setState(() {
        _diagnosis = result;
      });
    } catch (error) {
      if (mounted) _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() {
          detecting = false;
        });
      }
    }
  }

  Future<void> showPrecautions() async {
    final diagnosis = _diagnosis;
    if (diagnosis == null || diagnosis.isUnknown || precautionLoading) return;

    setState(() {
      precautionLoading = true;
    });
    try {
      var precautions = diseasePrecautions;
      if (precautions.isEmpty) {
        precautions = await apiService.sendDiseaseAdvice(
          diseaseName: diagnosis.displayName,
        );
      }
      if (!mounted) return;
      setState(() {
        diseasePrecautions = precautions;
      });
      _showSuccessDialog('คำแนะนำการดูแล', precautions);
    } catch (error) {
      if (mounted) _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() {
          precautionLoading = false;
        });
      }
    }
  }

  Future<void> _saveDataWithLocation() async {
    final diagnosis = _diagnosis;
    if (diagnosis == null || diagnosis.isUnknown || isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('กรุณาเปิด GPS (Location Services) บนอุปกรณ์ของคุณ');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธอย่างถาวร กรุณาไปตั้งค่าในเครื่อง',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latitude = position.latitude.toString();
      final longitude = position.longitude.toString();

      // TODO: บันทึก diseaseName, latitude และ longitude ลงฐานข้อมูลจริง
      debugPrint('===== บันทึกข้อมูลสำเร็จ =====');
      debugPrint('โรคที่พบ: ${diagnosis.displayName}');
      debugPrint('พิกัด: $latitude, $longitude');

      if (!mounted) return;
      _showSuccessDialog(
        'บันทึกข้อมูลสำเร็จ',
        'ชื่อโรค: ${diagnosis.displayName}\n'
            'ละติจูด: $latitude\n'
            'ลองจิจูด: $longitude',
      );
    } catch (error) {
      if (mounted) _showErrorSnackBar(error);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackBar(Object error) {
    var message = error.toString();
    message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
    message = message.replaceFirst(RegExp(r'^Error:\s*'), '');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFB3261E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _showSuccessDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: themeColor,
            size: 46,
          ),
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: themeColor),
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 14, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/plantcare_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.eco_rounded,
                color: themeColor,
                size: 42,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PlantCare AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'ผู้ช่วยตรวจสุขภาพพืชด้วย AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 10),
                _LiveBadge(),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ประวัติการตรวจ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HistoryPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เริ่มต้นตรวจโรคพืช',
            style: TextStyle(
              color: Color(0xFF163D1A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'เลือกรูปใบไม้ที่ต้องการตรวจ หรือถ่ายภาพใหม่',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'เลือกรูปภาพ',
                  onPressed:
                      detecting ? null : () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'เปิดกล้อง',
                  onPressed:
                      detecting ? null : () => _pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accentColor.withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 148,
            height: 148,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.45),
                width: 2,
              ),
            ),
            child: Image.asset(
              'assets/images/plantcare_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.eco_rounded,
                color: themeColor,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_rounded, color: themeColor, size: 22),
              SizedBox(width: 8),
              Text(
                'เริ่มตรวจสุขภาพพืช',
                style: TextStyle(
                  color: Color(0xFF1B3A20),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ภาพที่สว่าง เห็นใบชัด และมีต้นพืชอยู่กลางภาพ\n'
            'จะช่วยให้ AI วิเคราะห์ได้แม่นยำขึ้น',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.image_search_rounded, color: themeColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ภาพที่เลือก',
                    style: TextStyle(
                      color: Color(0xFF163D1A),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'พร้อมตรวจ',
                    style: TextStyle(
                      color: Color(0xFF246B29),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: const Color(0xFFE9F2E9),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('ไม่สามารถแสดงรูปภาพได้'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: detecting ? null : detectDisease,
          icon: detecting
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(detecting ? 'กำลังวิเคราะห์ภาพ...' : 'วิเคราะห์โรค'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            disabledBackgroundColor: themeColor.withOpacity(0.65),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(PlantDiagnosis diagnosis) {
    final isUnknown = diagnosis.isUnknown;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isUnknown
              ? Colors.orange.withOpacity(0.45)
              : accentColor.withOpacity(0.60),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUnknown
                      ? Colors.orange.withOpacity(0.14)
                      : accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isUnknown
                      ? Icons.help_outline_rounded
                      : Icons.health_and_safety_rounded,
                  color: isUnknown ? Colors.orange[800] : themeColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ผลการวิเคราะห์',
                  style: TextStyle(
                    color: Color(0xFF163D1A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                isUnknown ? 'ต้องถ่ายใหม่' : 'ประเมินแล้ว',
                style: TextStyle(
                  color: isUnknown ? Colors.orange[800] : themeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            diagnosis.diseaseThai,
            style: const TextStyle(
              color: Color(0xFF102B14),
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (diagnosis.diseaseEnglish.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              diagnosis.diseaseEnglish,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F9F3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'คำอธิบาย',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  diagnosis.descriptionThai,
                  style: const TextStyle(
                    color: Color(0xFF314434),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.menu_book_rounded, color: themeColor, size: 18),
              SizedBox(width: 7),
              Expanded(
                child: Tooltip(
                  message: plantDiseaseSourceUrl,
                  child: Text(
                    'อ้างอิง: RMA Agriculture • โรคพืชช่วงหน้าฝน',
                    style: TextStyle(
                      color: Color(0xFF56705A),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isUnknown) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: precautionLoading
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: themeColor,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: showPrecautions,
                          icon: const Icon(Icons.lightbulb_outline_rounded),
                          label: const Text('คำแนะนำ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeColor,
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: accentColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: isSaving
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: themeColor,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _saveDataWithLocation,
                          icon: const Icon(Icons.bookmark_add_rounded),
                          label: const Text('บันทึก'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'ลองถ่ายภาพใหม่ โดยให้ใบอยู่ในบริเวณที่มีแสงเพียงพอและไม่สั่นไหว',
              style: TextStyle(
                color: Colors.orange[900],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            children: [
              _buildHeader(),
              _buildActionCard(),
              if (_selectedImage == null)
                _buildEmptyState()
              else ...[
                _buildImagePreview(),
                _buildAnalyzeButton(),
              ],
              if (_diagnosis != null) _buildDiagnosisCard(_diagnosis!),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Color(0xFFB9F6CA), size: 9),
          SizedBox(width: 6),
          Text(
            'พร้อมวิเคราะห์',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
