import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class DocumentsRepository {
  DocumentsRepository(this._api);
  final ApiClient _api;

  Future<List<ListingDocumentDto>> forListing(int listingId) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/listings/$listingId/documents',
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(ListingDocumentDto.fromJson)
          .toList();
    }
    throw AuthException(
      'Could not load documents.',
      status: res.statusCode,
    );
  }

  Future<ListingDocumentDto> selfReport(int listingId, String kind) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/listings/$listingId/documents/$kind/self-report',
    );
    if (res.statusCode == 200 && res.data != null) {
      return ListingDocumentDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not self-report.',
      status: res.statusCode,
    );
  }

  Future<ListingDocumentDto> upload({
    required int listingId,
    required String kind,
    required String filename,
    Uint8List? bytes,
    String? path,
  }) async {
    assert(bytes != null || path != null);
    final file = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: filename)
        : await MultipartFile.fromFile(path!, filename: filename);
    final form = FormData.fromMap({'document': file});
    // Let Dio 5 set the multipart boundary automatically.
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/listings/$listingId/documents/$kind',
      data: form,
    );
    if (res.statusCode == 200 && res.data != null) {
      return ListingDocumentDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Upload failed.',
      status: res.statusCode,
    );
  }

  Future<void> delete(int listingId, String kind) async {
    final res = await _api.dio.delete('/listings/$listingId/documents/$kind');
    if (res.statusCode == 204) return;
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Delete failed.',
      status: res.statusCode,
    );
  }

  // ── admin ──

  Future<List<PendingDocumentDto>> pendingForAdmin() async {
    final res = await _api.dio.get<List<dynamic>>('/admin/documents/pending');
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(PendingDocumentDto.fromJson)
          .toList();
    }
    throw AuthException('Could not load queue.', status: res.statusCode);
  }

  Future<void> adminApprove(int documentId) async {
    final res =
        await _api.dio.post<Map<String, dynamic>>('/admin/documents/$documentId/approve');
    if (res.statusCode == 200) return;
    throw AuthException(
      _err(res.data) ?? 'Approve failed.',
      status: res.statusCode,
    );
  }

  Future<void> adminReject(int documentId, String reason) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/admin/documents/$documentId/reject',
      data: {'reason': reason},
    );
    if (res.statusCode == 200) return;
    throw AuthException(
      _err(res.data) ?? 'Reject failed.',
      status: res.statusCode,
    );
  }

  String? _err(Map<String, dynamic>? data) {
    if (data == null) return null;
    final fields = data['fields'];
    if (fields is Map && fields.isNotEmpty) {
      final entry = fields.entries.first;
      final val = entry.value;
      final msg = val is List && val.isNotEmpty ? val.first : val;
      return '${entry.key}: $msg';
    }
    if (fields is List && fields.isNotEmpty) return '${fields.first}';
    final err = data['error'];
    return err is String ? err : null;
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(ref.watch(apiClientProvider));
});
