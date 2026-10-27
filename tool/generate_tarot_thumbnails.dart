import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final source = Directory('assets/images');
  final output = Directory('assets/tarot_thumbs')..createSync(recursive: true);
  final files =
      source
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.webp'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final decoded = image.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      throw StateError('Cannot decode ${file.path}');
    }
    final resized = image.copyResize(
      decoded,
      width: 504,
      interpolation: image.Interpolation.average,
    );
    final name = file.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.webp$', caseSensitive: false),
      '.jpg',
    );
    File(
      '${output.path}${Platform.pathSeparator}$name',
    ).writeAsBytesSync(image.encodeJpg(resized, quality: 78));
  }

  stdout.writeln('Generated ${files.length} tarot thumbnails.');
}
