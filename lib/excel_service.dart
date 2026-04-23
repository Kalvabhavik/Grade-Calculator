import 'dart:typed_data';
import 'package:excel/excel.dart';

String _batchPrefix(String batch) => batch.split('-').first.trim();

String _deptCode(String dept) {
  switch (dept.toUpperCase()) {
    case 'CSE':
      return 'BCS';
    case 'ECE':
      return 'BEC';
    case 'DSAI':
      return 'BDA';
    default:
      return dept.toUpperCase();
  }
}

(int, int) _regRange(String dept, String? section) {
  switch (dept.toUpperCase()) {
    case 'CSE':
      if (section == 'A') return (1, 107);
      if (section == 'B') return (107, 215);
      return (1, 215);
    case 'ECE':
      return (1, 80);
    case 'DSAI':
      return (1, 110);
    default:
      return (1, 50);
  }
}

String _regNo(String batchPrefix, String deptCode, int idx) {
  return '$batchPrefix$deptCode${idx.toString().padLeft(3, '0')}';
}

CellStyle _headerStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#174C8F'),
    );

CellStyle _maxMarksStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#7B3F00'),
      backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
    );

CellStyle _lockedStyle() => CellStyle(
      fontColorHex: ExcelColor.fromHexString('#111827'),
      backgroundColorHex: ExcelColor.fromHexString('#EAF2FF'),
    );

CellStyle _hintStyle() => CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#64748B'),
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    );

void _writeCell(Sheet sheet, int row, int col, String value, CellStyle style) {
  final cell = sheet.cell(
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
  );
  cell.value = TextCellValue(value);
  cell.cellStyle = style;
}

String _cleanSheetName(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\[\]\:\*\?\/\\]'), '-');
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

class ExcelService {
  static Uint8List generateIndividualTemplate({
    required String batch,
    required String dept,
    String? section,
    required Map<String, int> divisions,
  }) {
    final excel = Excel.createExcel();
    final sheetName = _cleanSheetName(
      section != null ? '$dept-$section Individual' : '$dept Individual',
    );
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final prefix = _batchPrefix(batch);
    final deptCode = _deptCode(dept);
    final (start, end) = _regRange(dept, section);
    final divisionNames = divisions.keys.toList();

    _writeCell(sheet, 0, 0, 'Reg No', _headerStyle());
    _writeCell(sheet, 0, 1, 'Student Name', _headerStyle());
    for (int i = 0; i < divisionNames.length; i++) {
      _writeCell(sheet, 0, i + 2, divisionNames[i], _headerStyle());
    }

    _writeCell(sheet, 1, 0, '', _maxMarksStyle());
    _writeCell(sheet, 1, 1, 'Max Marks', _maxMarksStyle());
    for (int i = 0; i < divisionNames.length; i++) {
      _writeCell(sheet, 1, i + 2, '', _maxMarksStyle());
    }

    for (int regIndex = start; regIndex <= end; regIndex++) {
      final row = 2 + regIndex - start;
      _writeCell(sheet, row, 0, _regNo(prefix, deptCode, regIndex), _lockedStyle());
      _writeCell(sheet, row, 1, '', _lockedStyle());
      for (int i = 0; i < divisionNames.length; i++) {
        _writeCell(sheet, row, i + 2, '', _hintStyle());
      }
    }

    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 24);
    for (int i = 0; i < divisionNames.length; i++) {
      sheet.setColumnWidth(i + 2, 16);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List generateTeamTemplate({
    required String batch,
    required String dept,
    String? section,
    required Map<String, int> teamDivisions,
  }) {
    final excel = Excel.createExcel();
    final sheetName = _cleanSheetName(
      section != null ? '$dept-$section Team' : '$dept Team',
    );
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    final divisionNames = teamDivisions.keys.toList();

    _writeCell(sheet, 0, 0, 'Team ID', _headerStyle());
    _writeCell(sheet, 0, 1, 'Team Name', _headerStyle());
    _writeCell(sheet, 0, 2, 'Members Reg Nos', _headerStyle());
    for (int i = 0; i < divisionNames.length; i++) {
      _writeCell(sheet, 0, i + 3, divisionNames[i], _headerStyle());
    }

    _writeCell(sheet, 1, 0, '', _maxMarksStyle());
    _writeCell(sheet, 1, 1, '', _maxMarksStyle());
    _writeCell(sheet, 1, 2, 'Max Marks', _maxMarksStyle());
    for (int i = 0; i < divisionNames.length; i++) {
      _writeCell(sheet, 1, i + 3, '', _maxMarksStyle());
    }

    for (int i = 0; i < 40; i++) {
      final row = i + 2;
      _writeCell(sheet, row, 0, 'T${(i + 1).toString().padLeft(3, '0')}', _lockedStyle());
      _writeCell(sheet, row, 1, '', _hintStyle());
      _writeCell(sheet, row, 2, '', _hintStyle());
      for (int d = 0; d < divisionNames.length; d++) {
        _writeCell(sheet, row, d + 3, '', _hintStyle());
      }
    }

    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 34);
    for (int i = 0; i < divisionNames.length; i++) {
      sheet.setColumnWidth(i + 3, 16);
    }

    return Uint8List.fromList(excel.encode()!);
  }
}
