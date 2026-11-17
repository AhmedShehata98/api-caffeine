import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadBundledTestFonts() async {
  for (final font in [
    ('Inter', 'Inter[opsz,wght].ttf'),
    ('GoogleSansFlex', 'GoogleSansFlex.ttf'),
    ('JetBrainsMono', 'JetBrainsMono[wght].ttf'),
  ]) {
    await (FontLoader(font.$1)..addFont(
          File('assets/fonts/${font.$2}')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  }
  var directory = File(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 8; depth++) {
    final font = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (font.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      break;
    }
    directory = directory.parent;
  }
}
