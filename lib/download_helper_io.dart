import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveBytesImpl({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required bool isWeb,
}) async {
  // Desktop: prompt with a Save dialog.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final location = await getSaveLocation(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Excel workbook',
          extensions: const ['xlsx'],
          mimeTypes: [mimeType],
        ),
      ],
      suggestedName: suggestedName,
      confirmButtonText: 'Save',
    );
    if (location == null) return null;
    final file = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
    await file.saveTo(location.path);
    return location.path;
  }

  // Mobile: write to app documents directory.
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$suggestedName';
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return path;
}
