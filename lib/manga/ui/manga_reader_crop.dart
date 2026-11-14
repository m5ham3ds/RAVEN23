import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Finds the actual artwork bounds of a manga scan by trimming flat margins.
/// The returned rectangle is normalized (0..1), so it can be applied to
/// images at any display size without changing the source bytes.
ui.Rect? findMangaContentRect(
  Uint8List rgba,
  int width,
  int height, {
  int tolerance = 12,
  double maxFraction = .4,
}) {
  if (width < 2 || height < 2 || rgba.length < width * height * 4) {
    return null;
  }

  int offset(int x, int y) => (y * width + x) * 4;
  bool closeTo(int index, int r, int g, int b) =>
      (rgba[index] - r).abs() <= tolerance &&
      (rgba[index + 1] - g).abs() <= tolerance &&
      (rgba[index + 2] - b).abs() <= tolerance;

  final xStep = math.max(1, width ~/ 64).toInt();
  final yStep = math.max(1, height ~/ 64).toInt();

  bool flatRow(int y, int r, int g, int b) {
    for (var x = 0; x < width; x += xStep) {
      if (!closeTo(offset(x, y), r, g, b)) return false;
    }
    return closeTo(offset(width - 1, y), r, g, b);
  }

  bool flatColumn(int x, int r, int g, int b) {
    for (var y = 0; y < height; y += yStep) {
      if (!closeTo(offset(x, y), r, g, b)) return false;
    }
    return closeTo(offset(x, height - 1), r, g, b);
  }

  final maxY = (height * maxFraction).floor();
  final maxX = (width * maxFraction).floor();
  final topOffset = offset(0, 0);
  final topColor = (rgba[topOffset], rgba[topOffset + 1], rgba[topOffset + 2]);
  var top = 0;
  while (top < maxY && flatRow(top, topColor.$1, topColor.$2, topColor.$3)) {
    top++;
  }

  final bottomOffset = offset(0, height - 1);
  final bottomColor = (
    rgba[bottomOffset],
    rgba[bottomOffset + 1],
    rgba[bottomOffset + 2],
  );
  var bottom = height;
  while (bottom > height - maxY &&
      bottom > top + 1 &&
      flatRow(bottom - 1, bottomColor.$1, bottomColor.$2, bottomColor.$3)) {
    bottom--;
  }

  final leftOffset = offset(0, 0);
  final leftColor = (
    rgba[leftOffset],
    rgba[leftOffset + 1],
    rgba[leftOffset + 2],
  );
  var left = 0;
  while (left < maxX &&
      flatColumn(left, leftColor.$1, leftColor.$2, leftColor.$3)) {
    left++;
  }

  final rightOffset = offset(width - 1, 0);
  final rightColor = (
    rgba[rightOffset],
    rgba[rightOffset + 1],
    rgba[rightOffset + 2],
  );
  var right = width;
  while (right > width - maxX &&
      right > left + 1 &&
      flatColumn(right - 1, rightColor.$1, rightColor.$2, rightColor.$3)) {
    right--;
  }

  if (left == 0 && top == 0 && right == width && bottom == height) {
    return null;
  }
  return ui.Rect.fromLTRB(
    left / width,
    top / height,
    right / width,
    bottom / height,
  );
}

/// Decodes a source image at a bounded width to keep margin detection cheap.
Future<ui.Rect?> detectMangaContentBounds(Uint8List encodedBytes) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(encodedBytes, targetWidth: 256);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return findMangaContentRect(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
