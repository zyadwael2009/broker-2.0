// Messaging DTOs — mirror app/messaging/routes.py responses.

class ThreadCounterparty {
  ThreadCounterparty({
    required this.id,
    required this.fullName,
    required this.role,
    this.verificationStatus,
  });

  final int id;
  final String fullName;
  final String role;
  final String? verificationStatus;

  factory ThreadCounterparty.fromJson(Map<String, dynamic> j) =>
      ThreadCounterparty(
        id: j['id'] as int,
        fullName: j['full_name'] as String,
        role: j['role'] as String,
        verificationStatus: j['verification_status'] as String?,
      );
}

class ThreadDto {
  ThreadDto({
    required this.id,
    required this.listingId,
    this.listingTitle,
    this.counterparty,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
  });

  final int id;
  final int listingId;
  final String? listingTitle;
  final ThreadCounterparty? counterparty;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  factory ThreadDto.fromJson(Map<String, dynamic> j) => ThreadDto(
        id: j['id'] as int,
        listingId: j['listing_id'] as int,
        listingTitle: j['listing_title'] as String?,
        counterparty: j['counterparty'] == null
            ? null
            : ThreadCounterparty.fromJson(
                j['counterparty'] as Map<String, dynamic>),
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        lastMessage: j['last_message'] as String?,
        lastMessageAt: _parseDate(j['last_message_at']),
        createdAt: _parseDate(j['created_at']),
      );

  static DateTime? _parseDate(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }
}

class MessageDto {
  MessageDto({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    this.createdAt,
    this.readAt,
  });

  final int id;
  final int threadId;
  final int senderId;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory MessageDto.fromJson(Map<String, dynamic> j) => MessageDto(
        id: j['id'] as int,
        threadId: j['thread_id'] as int,
        senderId: j['sender_id'] as int,
        body: j['body'] as String,
        createdAt: ThreadDto._parseDate(j['created_at']),
        readAt: ThreadDto._parseDate(j['read_at']),
      );
}
