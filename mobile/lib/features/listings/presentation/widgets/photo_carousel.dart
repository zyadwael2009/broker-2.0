import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/env.dart';
import '../../../../theme.dart';
import '../../data/models.dart';

/// Swipeable photo gallery for the listing detail screen.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({super.key, required this.photos});
  final List<ListingPhotoDto> photos;

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
        aspectRatio: 16 / 10,
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
          aspectRatio: 16 / 10,
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
