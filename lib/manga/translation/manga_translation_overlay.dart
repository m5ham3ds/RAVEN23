import 'package:flutter/material.dart';

import 'manga_translation_models.dart';

/// Paints OCR translations over the original page using normalized source-image
/// coordinates, so translated bubbles remain aligned when the page is zoomed.
class MangaTranslationOverlay extends StatelessWidget {
  const MangaTranslationOverlay({
    required this.translation,
    required this.targetLanguage,
    this.fontSize = 13,
    this.backgroundOpacity = .94,
    this.fitMode = 'width',
    super.key,
  });

  final MangaPageTranslation translation;
  final String targetLanguage;
  final double fontSize;
  final double backgroundOpacity;
  final String fitMode;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _MangaTranslationPainter(
        translation: translation,
        isRtl: targetLanguage == 'ar' || targetLanguage == 'he',
        fontSize: fontSize,
        backgroundOpacity: backgroundOpacity,
        fitMode: fitMode,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _MangaTranslationPainter extends CustomPainter {
  const _MangaTranslationPainter({
    required this.translation,
    required this.isRtl,
    required this.fontSize,
    required this.backgroundOpacity,
    required this.fitMode,
  });

  final MangaPageTranslation translation;
  final bool isRtl;
  final double fontSize;
  final double backgroundOpacity;
  final String fitMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty ||
        translation.imageWidth <= 0 ||
        translation.imageHeight <= 0)
      return;
    final imageSize = Size(
      translation.imageWidth.toDouble(),
      translation.imageHeight.toDouble(),
    );
    final fitted = applyBoxFit(
      switch (fitMode) {
        'height' => BoxFit.fitHeight,
        'contain' => BoxFit.contain,
        _ => BoxFit.fitWidth,
      },
      imageSize,
      size,
    );
    final imageRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final background = Paint()
      ..color = Colors.white.withValues(
        alpha: backgroundOpacity.clamp(0.0, 1.0).toDouble(),
      );
    final border = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;

    for (final region in translation.regions) {
      final source = region.bounds;
      final rect = Rect.fromLTRB(
        imageRect.left + source.left * imageRect.width,
        imageRect.top + source.top * imageRect.height,
        imageRect.left + source.right * imageRect.width,
        imageRect.top + source.bottom * imageRect.height,
      );
      if (rect.width < 1 || rect.height < 1 || region.translated.trim().isEmpty)
        continue;
      final maxBubbleWidth = (size.width * .46)
          .clamp(42.0, size.width)
          .toDouble();
      final textPainter = TextPainter(
        text: TextSpan(
          text: region.translated,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize.clamp(9.0, 24.0).toDouble(),
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 5,
        ellipsis: '…',
      )..layout(maxWidth: maxBubbleWidth - 8);

      final bubbleWidth = (textPainter.width + 8)
          .clamp(34.0, maxBubbleWidth)
          .toDouble();
      final bubbleHeight = (textPainter.height + 6)
          .clamp(20.0, size.height)
          .toDouble();
      final left = (rect.center.dx - bubbleWidth / 2)
          .clamp(0.0, size.width - bubbleWidth)
          .toDouble();
      final top = (rect.center.dy - bubbleHeight / 2)
          .clamp(0.0, size.height - bubbleHeight)
          .toDouble();
      final bubble = Rect.fromLTWH(left, top, bubbleWidth, bubbleHeight);
      final rounded = RRect.fromRectAndRadius(bubble, const Radius.circular(3));
      canvas.drawRRect(rounded, background);
      canvas.drawRRect(rounded, border);
      textPainter.paint(
        canvas,
        Offset(
          bubble.left + (bubble.width - textPainter.width) / 2,
          bubble.top + (bubble.height - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MangaTranslationPainter oldDelegate) =>
      oldDelegate.translation != translation ||
      oldDelegate.isRtl != isRtl ||
      oldDelegate.fontSize != fontSize ||
      oldDelegate.backgroundOpacity != backgroundOpacity ||
      oldDelegate.fitMode != fitMode;
}
