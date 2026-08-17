// Listing DTOs — mirror `_listing_public_dict` on the backend.

import 'package:intl/intl.dart';

import '../../ratings/data/models.dart';

class ListingPhotoDto {
  ListingPhotoDto({
    required this.id,
    required this.url,
    required this.sortOrder,
  });

  final int id;
  final String url;
  final int sortOrder;

  factory ListingPhotoDto.fromJson(Map<String, dynamic> j) => ListingPhotoDto(
        id: j['id'] as int,
        url: j['url'] as String,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class ListingBrokerDto {
  ListingBrokerDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.verificationStatus,
    required this.rating,
  });
  final int id;
  final String fullName;
  final String phone;
  final String verificationStatus;
  final RatingAggregateDto rating;

  factory ListingBrokerDto.fromJson(Map<String, dynamic> j) => ListingBrokerDto(
        id: j['id'] as int,
        fullName: j['full_name'] as String,
        phone: j['phone'] as String,
        verificationStatus: j['verification_status'] as String,
        rating: j['rating'] is Map<String, dynamic>
            ? RatingAggregateDto.fromJson(j['rating'] as Map<String, dynamic>)
            : RatingAggregateDto.empty(),
      );
}

class ListingDto {
  ListingDto({
    required this.id,
    required this.title,
    required this.description,
    required this.priceEgp,
    required this.areaM2,
    required this.governorate,
    required this.city,
    required this.district,
    required this.lat,
    required this.lng,
    required this.propertyType,
    required this.status,
    required this.createdAt,
    required this.lastConfirmedAt,
    required this.expiresAt,
    required this.isExpired,
    required this.photos,
    this.broker,
    this.listingKind = 'sale',
    this.bedrooms,
    this.bathrooms,
    this.floorNumber,
    this.isFurnished,
    this.compoundName,
    this.deliveryStatus,
  });

  final int id;
  final String title;
  final String? description;
  final String priceEgp; // Decimal preserved as string
  final String areaM2;
  final String governorate;
  final String city;
  final String? district;
  final double? lat;
  final double? lng;
  final String propertyType; // 'apartment' | 'house' | 'villa' | 'land' | 'commercial'
  final String status; // 'active' | 'sold' | 'expired' | 'hidden'
  final DateTime? createdAt;
  final DateTime? lastConfirmedAt;
  final DateTime? expiresAt;
  final bool isExpired;
  final List<ListingPhotoDto> photos;
  final ListingBrokerDto? broker;

  // Phase A1 richer fields — all nullable; back-compat with older API.
  final String listingKind; // 'sale' | 'rent'
  final int? bedrooms;
  final int? bathrooms;
  final int? floorNumber;
  final bool? isFurnished;
  final String? compoundName;
  final String? deliveryStatus; // 'ready' | 'under_construction' | null

  factory ListingDto.fromJson(Map<String, dynamic> j) => ListingDto(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        priceEgp: (j['price_egp'] ?? '0') as String,
        areaM2: (j['area_m2'] ?? '0') as String,
        governorate: j['governorate'] as String,
        city: j['city'] as String,
        district: j['district'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        propertyType: j['property_type'] as String,
        status: j['status'] as String,
        createdAt: _parseDate(j['created_at']),
        lastConfirmedAt: _parseDate(j['last_confirmed_at']),
        expiresAt: _parseDate(j['expires_at']),
        isExpired: (j['is_expired'] as bool?) ?? false,
        photos: ((j['photos'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ListingPhotoDto.fromJson)
            .toList(),
        broker: j['broker'] == null
            ? null
            : ListingBrokerDto.fromJson(j['broker'] as Map<String, dynamic>),
        listingKind: (j['listing_kind'] as String?) ?? 'sale',
        bedrooms: (j['bedrooms'] as num?)?.toInt(),
        bathrooms: (j['bathrooms'] as num?)?.toInt(),
        floorNumber: (j['floor_number'] as num?)?.toInt(),
        isFurnished: j['is_furnished'] as bool?,
        compoundName: j['compound_name'] as String?,
        deliveryStatus: j['delivery_status'] as String?,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }

  /// Human-friendly price like "3,500,000 EGP" (Egyptian locale-ish grouping).
  String get priceDisplay {
    final n = double.tryParse(priceEgp) ?? 0;
    final f = NumberFormat.decimalPattern('en_US');
    return '${f.format(n)} EGP';
  }

  String get areaDisplay {
    final n = double.tryParse(areaM2) ?? 0;
    if (n == n.roundToDouble()) return '${n.toInt()} m²';
    return '${n.toStringAsFixed(1)} m²';
  }

  /// Days remaining until auto-expire (may be negative for already expired).
  int? daysUntilExpiry() {
    if (expiresAt == null) return null;
    return expiresAt!.toLocal().difference(DateTime.now()).inDays;
  }
}
