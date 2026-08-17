import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class ListingsRepository {
  ListingsRepository(this._api);
  final ApiClient _api;

  Future<List<ListingDto>> browse({
    String? governorate,
    String? city,
    String? propertyType,
    String? minPrice,
    String? maxPrice,
    // Phase A3-tail — richer filter parity with the Jinja /browse row.
    String? kind,          // 'sale' | 'rent'
    int? bedroomsMin,
    bool? furnished,
    String? compound,
    String? deliveryStatus,
  }) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/listings',
      queryParameters: {
        if (governorate != null && governorate.isNotEmpty) 'governorate': governorate,
        if (city != null && city.isNotEmpty) 'city': city,
        if (propertyType != null) 'property_type': propertyType,
        if (minPrice != null && minPrice.isNotEmpty) 'min_price': minPrice,
        if (maxPrice != null && maxPrice.isNotEmpty) 'max_price': maxPrice,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (bedroomsMin != null) 'bedrooms_min': bedroomsMin,
        if (furnished != null) 'furnished': furnished ? 'true' : 'false',
        if (compound != null && compound.isNotEmpty) 'compound': compound,
        if (deliveryStatus != null && deliveryStatus.isNotEmpty) 'delivery_status': deliveryStatus,
      },
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!.cast<Map<String, dynamic>>().map(ListingDto.fromJson).toList();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load listings.',
      status: res.statusCode,
    );
  }

  Future<List<ListingDto>> mine() async {
    final res = await _api.dio.get<List<dynamic>>('/listings/mine');
    if (res.statusCode == 200 && res.data != null) {
      return res.data!.cast<Map<String, dynamic>>().map(ListingDto.fromJson).toList();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load your listings.',
      status: res.statusCode,
    );
  }

  Future<ListingDto> get(int id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/listings/$id');
    if (res.statusCode == 200 && res.data != null) {
      return ListingDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Listing not found.',
      status: res.statusCode,
    );
  }

  Future<ListingDto> create(Map<String, dynamic> body) async {
    final res = await _api.dio.post<Map<String, dynamic>>('/listings', data: body);
    if (res.statusCode == 201 && res.data != null) {
      return ListingDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not create listing.',
      status: res.statusCode,
    );
  }

  Future<ListingDto> update(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch<Map<String, dynamic>>('/listings/$id', data: body);
    if (res.statusCode == 200 && res.data != null) {
      return ListingDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not update listing.',
      status: res.statusCode,
    );
  }

  Future<void> delete(int id) async {
    final res = await _api.dio.delete('/listings/$id');
    if (res.statusCode == 204) return;
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not delete listing.',
      status: res.statusCode,
    );
  }

  Future<ListingDto> confirm(int id) async {
    final res = await _api.dio.post<Map<String, dynamic>>('/listings/$id/confirm');
    if (res.statusCode == 200 && res.data != null) {
      return ListingDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not confirm listing.',
      status: res.statusCode,
    );
  }

  /// [documentBytes] on web, [documentPath] on native.
  Future<ListingPhotoDto> uploadPhoto({
    required int listingId,
    required String filename,
    String? path,
    Uint8List? bytes,
  }) async {
    assert(path != null || bytes != null);
    final photo = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: filename)
        : await MultipartFile.fromFile(path!, filename: filename);
    final form = FormData.fromMap({'photo': photo});

    // Let Dio 5 set the multipart boundary automatically. Manually
    // setting contentType strips the boundary → server sends 400.
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/listings/$listingId/photos',
      data: form,
    );
    if (res.statusCode == 201 && res.data != null) {
      return ListingPhotoDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Photo upload failed.',
      status: res.statusCode,
    );
  }

  Future<void> deletePhoto(int listingId, int photoId) async {
    final res = await _api.dio.delete('/listings/$listingId/photos/$photoId');
    if (res.statusCode == 204) return;
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not delete photo.',
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

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  return ListingsRepository(ref.watch(apiClientProvider));
});
