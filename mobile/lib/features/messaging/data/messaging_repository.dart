import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class MessagingRepository {
  MessagingRepository(this._api);
  final ApiClient _api;

  Future<ThreadDto> startOrGetThread(int listingId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/threads',
      data: {'listing_id': listingId},
    );
    if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
      return ThreadDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not open conversation.',
      status: res.statusCode,
    );
  }

  Future<ThreadDto> getThread(int threadId) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/threads/$threadId');
    if (res.statusCode == 200 && res.data != null) {
      return ThreadDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not load conversation.',
      status: res.statusCode,
    );
  }

  Future<List<ThreadDto>> listThreads() async {
    final res = await _api.dio.get<List<dynamic>>('/threads');
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(ThreadDto.fromJson)
          .toList();
    }
    throw AuthException('Could not load conversations.', status: res.statusCode);
  }

  /// [since] enables delta polling — only messages with id > since are
  /// returned. Omit to get the last 50 (fresh open).
  Future<List<MessageDto>> messages(int threadId, {int? since}) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/threads/$threadId/messages',
      queryParameters: {if (since != null) 'since': since},
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(MessageDto.fromJson)
          .toList();
    }
    throw AuthException('Could not load messages.', status: res.statusCode);
  }

  Future<MessageDto> send(int threadId, String body) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/threads/$threadId/messages',
      data: {'body': body},
    );
    if (res.statusCode == 201 && res.data != null) {
      return MessageDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Send failed.',
      status: res.statusCode,
    );
  }

  Future<void> markRead(int threadId) async {
    await _api.dio.post('/threads/$threadId/read');
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

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(apiClientProvider));
});
