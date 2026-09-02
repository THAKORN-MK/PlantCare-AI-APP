const String plantDiseaseSourceUrl =
    'https://rmaagriculture.com/th/2022/05/26/plant-diseases-in-the-rainy-season/';

/// Short, prompt-sized reference notes based on the supplied RMA Agriculture
/// article. They help the model return Thai explanations consistently.
const String plantDiseaseReferencePrompt = '''
ข้อมูลอ้างอิงโรคพืชช่วงหน้าฝน:
- โรคราน้ำค้าง (Downy mildew): ใบมีปื้นเหลืองด้านบน และอาจพบผงสีขาวหรือเทาใต้ใบเมื่ออากาศชื้นและเย็น
- โรคเน่าคอดิน (Damping off): ต้นกล้าโคนต้นเน่า ล้ม หรือยุบใกล้ผิวดิน มักสัมพันธ์กับน้ำขังและอากาศถ่ายเทไม่ดี
- โรคใบจุด (Alternaria leaf spot): ใบมีจุดหรือแผลสีน้ำตาลถึงดำ บางแผลเป็นวงซ้อนและทำให้เนื้อเยื่อรอบข้างเหลือง
- โรคราสนิมขาว (White rust): ด้านบนใบมีจุดเหลือง และด้านใต้ใบอาจมีตุ่มนูนสีขาวในสภาพชื้นแฉะ
- โรคเหี่ยว (Fusarium wilt): ใบล่างเหลืองและเหี่ยวลามขึ้นด้านบน อาจพบวงสีน้ำตาลในท่อลำเลียงเมื่อผ่าลำต้น
ให้ใช้ข้อมูลนี้เป็นแนวทางประกอบภาพเท่านั้น หากภาพไม่ชัดหรือไม่ตรงลักษณะ ให้ระบุว่าไม่สามารถยืนยันได้
แหล่งข้อมูล: $plantDiseaseSourceUrl
''';
