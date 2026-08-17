import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'document_opener_native.dart'
    if (dart.library.html) 'document_opener_web.dart' as impl;

/// Open a document (PDF or image) by its bytes.
///
/// Web: builds a Blob + object URL and opens it in a new tab — the
/// browser's own PDF viewer handles it, no size cap.
///
/// Native: writes to the app's temp dir and opens with the OS handler
/// via `open_filex`. Avoids the two limits the old data:-URI viewer hit:
///  - Chrome for Android rejects top-level data: URLs (since Chrome 60)
///  - Android's Binder Intent extras cap trips on any file > ~700 KB
///
/// Callers should show the error message if [success] is false.
Future<DocumentOpenResult> openDocumentBytes({
  required Uint8List bytes,
  required String filenameWithExt,
  BuildContext? context,
}) {
  if (kIsWeb) {
    return impl.openWeb(bytes: bytes, filename: filenameWithExt);
  }
  return impl.openNative(bytes: bytes, filename: filenameWithExt);
}

class DocumentOpenResult {
  DocumentOpenResult({required this.success, this.error});
  final bool success;
  final String? error;
}
