// Per-listing document DTOs. Mirrors app/documents/routes.py responses.

/// Server-side enum values, kept as strings so extending the backend
/// (add a "utilities" doc, etc.) doesn't force a client rebuild.
class DocumentKinds {
  static const titleDeed = 'title_deed';
  static const noLiens = 'no_liens';
  static const taxClearance = 'tax_clearance';

  /// Canonical order — the buyer-facing checklist renders in this order.
  static const all = [titleDeed, noLiens, taxClearance];

  static String label(String kind) {
    switch (kind) {
      case titleDeed:
        return 'Title deed registered at notary';
      case noLiens:
        return 'No liens or disputes';
      case taxClearance:
        return 'Tax clearance';
      default:
        return kind;
    }
  }

  static String shortLabel(String kind) {
    switch (kind) {
      case titleDeed:
        return 'Title deed';
      case noLiens:
        return 'No liens';
      case taxClearance:
        return 'Tax clearance';
      default:
        return kind;
    }
  }
}

class DocumentStates {
  static const unset = 'unset';
  static const selfReported = 'self_reported';
  static const pending = 'pending';
  static const verified = 'verified';
  static const rejected = 'rejected';
}

class ListingDocumentDto {
  ListingDocumentDto({
    required this.id,
    required this.listingId,
    required this.kind,
    required this.state,
    required this.hasDocument,
    this.verifiedAt,
    this.rejectionReason,
  });

  /// null for `unset` rows — the backend synthesises those without a DB row.
  final int? id;
  final int listingId;
  final String kind;
  final String state;
  final bool hasDocument;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  factory ListingDocumentDto.fromJson(Map<String, dynamic> j) {
    final rawVerifiedAt = j['verified_at'] as String?;
    return ListingDocumentDto(
      id: j['id'] as int?,
      listingId: j['listing_id'] as int,
      kind: j['kind'] as String,
      state: j['state'] as String,
      hasDocument: (j['has_document'] as bool?) ?? false,
      verifiedAt:
          rawVerifiedAt == null ? null : DateTime.tryParse(rawVerifiedAt),
      rejectionReason: j['rejection_reason'] as String?,
    );
  }

  bool get isUnset => state == DocumentStates.unset;
  bool get isVerified => state == DocumentStates.verified;
  bool get isPending => state == DocumentStates.pending;
  bool get isRejected => state == DocumentStates.rejected;
  bool get isSelfReported => state == DocumentStates.selfReported;
}

/// Payload shape used in the admin queue.
class PendingDocumentDto {
  PendingDocumentDto({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.kind,
    this.documentUrl,
    this.brokerName,
    this.brokerPhone,
    this.updatedAt,
  });

  final int id;
  final int listingId;
  final String listingTitle;
  final String kind;
  final String? documentUrl;
  final String? brokerName;
  final String? brokerPhone;
  final DateTime? updatedAt;

  factory PendingDocumentDto.fromJson(Map<String, dynamic> j) {
    final broker = j['broker'] as Map<String, dynamic>?;
    final rawUpdated = j['updated_at'] as String?;
    return PendingDocumentDto(
      id: j['id'] as int,
      listingId: j['listing_id'] as int,
      listingTitle: j['listing_title'] as String,
      kind: j['kind'] as String,
      documentUrl: j['document_url'] as String?,
      brokerName: broker?['full_name'] as String?,
      brokerPhone: broker?['phone'] as String?,
      updatedAt: rawUpdated == null ? null : DateTime.tryParse(rawUpdated),
    );
  }
}
