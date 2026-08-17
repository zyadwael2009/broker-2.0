import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'document_opener.dart';

/// Native implementation: write bytes to `${tempDir}/broker-docs/<name>`
/// and hand it to the OS via `open_filex`. Handles arbitrarily large
/// files — the OS renders using its own PDF/image viewer.
Future<DocumentOpenResult> openNative({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/broker-docs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    final res = await OpenFilex.open(file.path);
    if (res.type == ResultType.done) {
      return DocumentOpenResult(success: true);
    }
    return DocumentOpenResult(success: false, error: res.message);
  } catch (e) {
    return DocumentOpenResult(success: false, error: '$e');
  }
}

/// Web stub — never invoked on native platforms (conditional import in
/// document_opener.dart routes web callers to the .web.dart variant).
Future<DocumentOpenResult> openWeb({
  required Uint8List bytes,
  required String filename,
}) async {
  return DocumentOpenResult(
    success: false,
    error: 'openWeb called on native platform',
  );
}
