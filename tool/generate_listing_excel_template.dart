import 'dart:io';

import 'package:excel/excel.dart';

void main() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'ที่พัก');
  final listings = workbook['ที่พัก'];
  listings.appendRow(
    [
      'ชื่อที่พัก',
      'หมวดหมู่',
      'ราคาต่ำสุด',
      'ราคาสูงสุด',
      'สกุลเงิน',
      'แขวง',
      'เมือง',
      'บ้าน',
      'ที่อยู่',
      'เบอร์โทร',
      'ลิงก์ต้นทาง',
      'Google Maps',
      'thumbnail_url',
    ].map(TextCellValue.new).toList(),
  );

  final examples = [
    [
      'ห้องแถวตัวอย่าง',
      'ห้องแถว',
      800000,
      1000000,
      'LAK',
      'นครหลวงเวียงจันทน์',
      'เมือง ไชเสดถา',
      'บ้าน ดงโดก',
      'ใกล้ตลาดและถนนใหญ่',
      '020xxxxxxxx',
      '',
      '17.908634442903843, 102.63205905992898',
      '',
    ],
    [
      'อพาร์ตเมนต์ตัวอย่าง',
      'อพาร์ตเมนต์',
      1500000,
      2500000,
      'LAK',
      'นครหลวงเวียงจันทน์',
      'เมือง จันทะบูลี',
      'บ้าน สีหอม',
      '',
      '',
      '',
      'https://maps.app.goo.gl/example',
      'https://example.com/thumbnail.jpg',
    ],
    [
      'บ้านเช่าตัวอย่าง',
      'บ้านเช่า',
      3000000,
      5000000,
      'LAK',
      'นครหลวงเวียงจันทน์',
      'เมือง สีโคดตะบอง',
      'บ้าน ตัวอย่าง',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'คอนโดตัวอย่าง',
      'คอนโด',
      500,
      700,
      'USD',
      'นครหลวงเวียงจันทน์',
      'เมือง ศรีสัตตนาค',
      'บ้าน ตัวอย่าง',
      '',
      '',
      '',
      '',
      '',
    ],
  ];
  for (final row in examples) {
    listings.appendRow(
      row
          .map(
            (value) => value is int
                ? IntCellValue(value)
                : TextCellValue(value.toString()),
          )
          .toList(),
    );
  }

  final instructions = workbook['คำแนะนำ'];
  final notes = [
    ['หัวข้อ', 'รายละเอียด'],
    ['คอลัมน์บังคับ', 'ชื่อที่พัก, ราคาต่ำสุด, ราคาสูงสุด, แขวง'],
    ['หมวดหมู่', 'ห้องแถว, อพาร์ตเมนต์, บ้านเช่า, คอนโด'],
    ['สกุลเงิน', 'LAK, THB หรือ USD (ถ้าเว้นว่างจะใช้ LAK)'],
    ['Google Maps', 'ใส่ Google Maps link หรือพิกัด latitude, longitude'],
    ['thumbnail_url', 'ใส่ URL รูปออนไลน์ หรือเว้นว่าง'],
    ['หลายไฟล์', 'หน้า Admin สามารถเลือกไฟล์ .xlsx หลายไฟล์พร้อมกันได้'],
  ];
  for (final row in notes) {
    instructions.appendRow(row.map(TextCellValue.new).toList());
  }

  final output = Directory('templates');
  output.createSync(recursive: true);
  final bytes = workbook.save();
  if (bytes == null) throw StateError('สร้างไฟล์ Excel ไม่สำเร็จ');
  File(
    '${output.path}${Platform.pathSeparator}room_rental_import_template.xlsx',
  ).writeAsBytesSync(bytes, flush: true);
}
