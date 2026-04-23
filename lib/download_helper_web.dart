import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web download via a Blob + synthetic anchor click. Works in all modern
/// browsers and is immune to the file_selector save-dialog no-op on web.
Future<String?> saveBytesImpl({
  required Uint8List bytes,
  required String suggestedName,
  required String mimeType,
  required bool isWeb,
}) async {
  // Some older browsers need a data URL fallback, but modern Chromium/Firefox
  // handle Blob URLs fine.
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final urlObj = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = urlObj
      ..download = suggestedName
      ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {
    // Extremely defensive fallback: navigate the tab to a data URL.
    final b64 = base64Encode(bytes);
    web.window.open('data:$mimeType;base64,$b64', '_blank');
  } finally {
    web.URL.revokeObjectURL(urlObj);
  }
  return 'Downloaded as $suggestedName';
}
