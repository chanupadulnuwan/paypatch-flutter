import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  final String? url;
  final double radius;
  final String fallbackText;
  final Color? fallbackColor;
  final Widget? overlayIcon;

  const NetImage({
    super.key,
    this.url,
    this.radius = 26,
    this.fallbackText = '?',
    this.fallbackColor,
    this.overlayIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = fallbackColor ?? cs.primary.withValues(alpha: 0.12);
    final fgColor = fallbackColor != null
        ? Colors.white
        : cs.primary;

    Widget avatar;
    if (url == null || url!.isEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: overlayIcon ?? Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.7,
          ),
        ),
      );
    } else {
      avatar = CachedNetworkImage(
        imageUrl: url!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor.withValues(alpha: 0.5),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: overlayIcon ?? Text(
            fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.7,
            ),
          ),
        ),
      );
    }

    return avatar;
  }
}
