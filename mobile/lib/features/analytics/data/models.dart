// DTOs for /brokers/me/analytics — nullable-safe throughout so a
// broker viewing this screen on the day their first listing goes live
// doesn't get a null-access crash.

class AnalyticsSummaryDto {
  AnalyticsSummaryDto({
    required this.viewsLast7d,
    required this.viewsLast30d,
    required this.messagesLast7d,
    required this.activeListings,
    required this.avgRating,
    required this.reviewsCount,
    required this.totalViews,
  });

  final int viewsLast7d;
  final int viewsLast30d;
  final int messagesLast7d;
  final int activeListings;
  final double avgRating;
  final int reviewsCount;
  final int totalViews;

  factory AnalyticsSummaryDto.fromJson(Map<String, dynamic> j) =>
      AnalyticsSummaryDto(
        viewsLast7d: (j['views_last_7d'] as num?)?.toInt() ?? 0,
        viewsLast30d: (j['views_last_30d'] as num?)?.toInt() ?? 0,
        messagesLast7d: (j['messages_last_7d'] as num?)?.toInt() ?? 0,
        activeListings: (j['active_listings'] as num?)?.toInt() ?? 0,
        avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 0.0,
        reviewsCount: (j['reviews_count'] as num?)?.toInt() ?? 0,
        totalViews: (j['total_views'] as num?)?.toInt() ?? 0,
      );
}

class DailyViewDto {
  DailyViewDto({required this.day, required this.count});
  final DateTime day;
  final int count;

  factory DailyViewDto.fromJson(Map<String, dynamic> j) => DailyViewDto(
        day: DateTime.parse(j['day'] as String),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class ListingAnalyticsDto {
  ListingAnalyticsDto({
    required this.id,
    required this.title,
    required this.viewsLast7d,
    required this.viewsLast30d,
    required this.messagesLast7d,
    required this.totalViews,
  });

  final int id;
  final String title;
  final int viewsLast7d;
  final int viewsLast30d;
  final int messagesLast7d;
  final int totalViews;

  factory ListingAnalyticsDto.fromJson(Map<String, dynamic> j) =>
      ListingAnalyticsDto(
        id: j['id'] as int,
        title: j['title'] as String,
        viewsLast7d: (j['views_last_7d'] as num?)?.toInt() ?? 0,
        viewsLast30d: (j['views_last_30d'] as num?)?.toInt() ?? 0,
        messagesLast7d: (j['messages_last_7d'] as num?)?.toInt() ?? 0,
        totalViews: (j['total_views'] as num?)?.toInt() ?? 0,
      );
}

class AnalyticsPayloadDto {
  AnalyticsPayloadDto({
    required this.summary,
    required this.viewsDaily,
    required this.byListing,
  });

  final AnalyticsSummaryDto summary;
  final List<DailyViewDto> viewsDaily;
  final List<ListingAnalyticsDto> byListing;

  factory AnalyticsPayloadDto.fromJson(Map<String, dynamic> j) =>
      AnalyticsPayloadDto(
        summary: AnalyticsSummaryDto.fromJson(
            j['summary'] as Map<String, dynamic>),
        viewsDaily: ((j['views_daily'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DailyViewDto.fromJson)
            .toList(),
        byListing: ((j['by_listing'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ListingAnalyticsDto.fromJson)
            .toList(),
      );
}
