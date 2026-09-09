import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/env.dart';
import '../../../../theme.dart';
import '../../data/models.dart';

/// Swipeable photo gallery for the listing detail screen.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    super.key,
    required this.photos,
    this.showCounter = false,
    this.aspectRatio = 16 / 10,
  });

  final List<ListingPhotoDto> photos;

  /// Renders the "3 / 8" chip from the Stitch mockup. Lives in here
  /// rather than in a caller's Stack because only the carousel knows
  /// which page is showing.
  final bool showCounter;
  final double aspectRatio;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: c.surfaceAlt,
          alignment: Alignment.center,
          child: Icon(Icons.image_rounded, color: c.textSubtle, size: 44),
        ),
      );
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = widget.photos[i];
              return CachedNetworkImage(
                imageUrl: '${Env.apiBaseUrl}${p.url}',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: c.surfaceAlt),
                errorWidget: (_, __, ___) => Container(
                  color: c.surfaceAlt,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_rounded, color: c.textSubtle),
                ),
              );
            },
          ),
        ),
        if (widget.showCounter && widget.photos.length > 1)
          PositionedDirectional(
            top: 12,
            start: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    '${_index + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photos.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white70,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
