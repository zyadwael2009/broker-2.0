import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses an image on-device before upload.
///
/// Egyptian mobile data is expensive and 3G is common outside major cities —
/// a 12MP camera photo can burn 5–10 MB where 2 MB looks identical on any
/// phone screen. This helper resizes to a max longer-edge of [maxEdge] px
/// and re-encodes at [quality] (JPEG-scale, 0–100).
///
/// Behavior:
///   * Small images (< 400 KB) are returned unchanged — the picker already
///     handed us something reasonable and re-encoding wastes CPU.
///   * Bytes that don't look like a supported image are returned unchanged
///     so the upload still happens (server will reject if truly invalid).
///   * JPEG in → JPEG out; PNG in → PNG out; WebP in → JPEG out
///     (flutter_image_compress can't emit WebP everywhere).
///   * EXIF metadata is stripped — a phone photo carries GPS a broker
///     didn't intend to share.
Future<Uint8List> compressImage(
  Uint8List raw, {
  int maxEdge = 1920,
  int quality = 82,
}) async {
  if (raw.length < 400 * 1024) return raw;

  final format = _detectFormat(raw);
  if (format == null) return raw; // not an image we know how to compress

  try {
    final out = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: maxEdge,
      minHeight: maxEdge,
      quality: quality,
      format: format,
      keepExif: false,
    );
    // Some encoders round-trip larger than the input (very small,
    // already-optimized images). Keep whichever is smaller.
    return out.length < raw.length ? Uint8List.fromList(out) : raw;
  } catch (_) {
    return raw; // never block an upload because of compression
  }
}

/// Native-only variant that reads directly from a filesystem path — avoids
/// pulling the whole file into the Dart heap when we already have a path.
/// Never call on web (there is no path); falls back to [compressImage] if
/// the plugin refuses.
Future<Uint8List> compressImageFromPath(
  String path, {
  int maxEdge = 1920,
  int quality = 82,
}) async {
  if (kIsWeb) {
    // Should never happen — web paths are opaque. Callers guard on kIsWeb
    // and pass bytes instead. Return an empty list rather than crash.
    return Uint8List(0);
  }
  try {
    final out = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: maxEdge,
      minHeight: maxEdge,
      quality: quality,
      keepExif: false,
    );
    if (out == null) return Uint8List(0);
    return Uint8List.fromList(out);
  } catch (_) {
    return Uint8List(0);
  }
}

/// Reads the magic-byte header and returns the [CompressFormat] to emit.
/// Returns null for unknown / non-image bytes (caller passes them through
/// unchanged so PDFs and other blobs are safe to hand to this function).
CompressFormat? _detectFormat(Uint8List bytes) {
  if (bytes.length < 12) return null;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return CompressFormat.jpeg;
  }
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return CompressFormat.png;
  }
  // WebP: RIFF....WEBP
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    // flutter_image_compress emits WebP on some platforms only — safest
    // to transcode to JPEG.
    return CompressFormat.jpeg;
  }
  return null;
}
