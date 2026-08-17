// Web-only implementation using dart:html Blob + object URL. Opens the
// browser's native viewer in a new tab; no size cap.
//
// This file is picked by the conditional import in document_opener.dart
// only when dart.library.html is present, so importing dart:html here is
// safe — the native build never compiles it.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'document_opener.dart';

Future<DocumentOpenResult> openWeb({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final mime = _mimeFor(filename);
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    // Trigger an anchor click with target=_blank — browsers treat this
    // as a user-initiated navigation so popup blockers don't fire, and
    // it works uniformly across Chrome/Firefox/Safari/Edge. Setting
    // `download` also gives the file a sane name when the user saves.
    final a = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(a);
    a.click();
    a.remove();
    // Give the browser a moment to attach, then release the URL.
    Future.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
    return DocumentOpenResult(success: true);
  } catch (e) {
    return DocumentOpenResult(success: false, error: '$e');
  }
}

Future<DocumentOpenResult> openNative({
  required Uint8List bytes,
  required String filename,
}) async {
  return DocumentOpenResult(
    success: false,
    error: 'openNative called on web platform',
  );
}

String _mimeFor(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}
