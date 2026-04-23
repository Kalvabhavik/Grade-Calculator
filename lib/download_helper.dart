import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'download_helper_io.dart'
  if (dart.library.js_interop) 'download_helper_web.dart' as impl;

/// Save bytes as a file the user can access.
///
/// * Web: triggers a real browser download (fixes "Download Template does
///   nothing" — `file_selector`'s save dialog silently no-ops on web).
/// * Desktop: opens a Save dialog via `file_selector`.
/// * Mobile: writes to the app's documents directory and returns the path.
///
/// Returns a short human-readable description of where the file ended up
/// (or `null` if the user cancelled a Save dialog).
Future<String?> saveBytes({
  required Uint8List bytes,
  required String suggestedName,
  String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}) =>
    impl.saveBytesImpl(
      bytes: bytes,
      suggestedName: suggestedName,
      mimeType: mimeType,
      isWeb: kIsWeb,
    );
