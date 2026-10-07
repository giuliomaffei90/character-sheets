import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:schede_png/main.dart';
import 'package:schede_png/sheet.dart';

void main() {
  test('il riquadro del ritratto resta dentro l\'immagine', () {
    final r = region(const Size(1000, 500), 2, 0, 1);
    expect(r.rect.left, closeTo(0, 1e-9));
    expect(r.rect.bottom, closeTo(500, 1e-9));
    expect(region(const Size(1000, 500), 1, .5, .5).rect.height, closeTo(500, 1e-9));
  });

  test('il PDF si genera con campi compilati, vuoti e ritratto', () async {
    final bytes = await buildSheet(
      {'nome': 'Brunilde', 'forza': '16', 'azioni': 'Martello da guerra. ' * 300},
      (rgba: Uint8List(4 * 4 * 4), width: 4, height: 4),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
