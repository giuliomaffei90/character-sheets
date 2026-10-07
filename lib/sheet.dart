// Scheda PNG in stile pergamena (A4, due pagine).
// I campi compilati sono disegnati come testo, quelli vuoti restano compilabili nel PDF.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

const labels = {
  'nome': 'NOME',
  'classe_livello': 'CLASSE / LIVELLO',
  'tipo_taglia': 'CREATURA / TAGLIA',
  'occupazione_storia': 'OCCUPAZIONE E STORIA',
  'aspetto': 'ASPETTO',
  'dote': 'DOTE',
  'ideale': 'IDEALE',
  'modi_fare': 'MODI DI FARE',
  'legame': 'LEGAME',
  'interazione': 'INTERAZIONE CON GLI ALTRI',
  'difetti_segreti': 'DIFETTI O SEGRETI',
  'conoscenze': 'CONOSCENZE UTILI',
  'forza': 'FOR',
  'destrezza': 'DES',
  'costituzione': 'COS',
  'intelligenza': 'INT',
  'saggezza': 'SAG',
  'carisma': 'CAR',
  'ca': 'CA',
  'pf': 'PF',
  'velocita': 'VELOCITÀ',
  'armatura_fonte': 'ARMATURA / FONTE',
  'tiri_salvezza': 'TIRI SALVEZZA',
  'abilita': 'ABILITÀ',
  'sensi': 'SENSI',
  'linguaggi': 'LINGUAGGI',
  'azioni': 'AZIONI',
  'incantesimi_giornalieri': 'INCANTESIMI E USI GIORNALIERI',
  'capacita_passive': 'TRATTI, AURE E CAPACITÀ PASSIVE',
  'equipaggiamento': 'ARMI, EQUIPAGGIAMENTO E OGGETTI',
  'note': 'NOTE AGGIUNTIVE',
};

/// Ritratto già ritagliato: pixel RGBA.
typedef Portrait = ({Uint8List rgba, int width, int height});

const _w = 595.2755905511812, _h = 841.8897637795277; // A4 in punti
const _m = 28.0; // margine cornice esterna
const _l = 42.0, _r = _w - 42, _g = 10.0; // colonna sinistra, destra, gap
const _colW = (_r - _l - _g) / 2;
const _px = 362.0, _py = 80.0, _pw = _r - 362, _ph = 184.0; // riquadro ritratto
const portraitAspect = _ph / _pw; // altezza / larghezza

final _ink = PdfColor.fromInt(0xFF6B3A2B), _paper = PdfColor.fromInt(0xFFF7F2EA), _box = PdfColor.fromInt(0xFFEEE6DC);

// Georgia su macOS e Windows (stesso aspetto ovunque), DejaVu su Linux
const _fonts = [
  ['/System/Library/Fonts/Supplemental/Georgia.ttf', '/System/Library/Fonts/Supplemental/Georgia Bold.ttf'],
  ['C:/Windows/Fonts/georgia.ttf', 'C:/Windows/Fonts/georgiab.ttf'],
  ['/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'],
];

Future<Uint8List> buildSheet(Map<String, String> data, [Portrait? portrait]) {
  final s = _Sheet(data);
  s.page1(portrait);
  s.page2();
  return s.doc.save();
}

double _t(double y) => _h - y; // coordinate dall'alto -> PDF

class _Sheet {
  _Sheet(this.data) {
    final f = _fonts.firstWhere(
      (f) => File(f[0]).existsSync(),
      orElse: () => throw StateError('Nessun font serif trovato: installa Georgia o DejaVu Serif'),
    );
    serif = PdfTtfFont(doc, ByteData.sublistView(File(f[0]).readAsBytesSync()));
    black = PdfTtfFont(doc, ByteData.sublistView(File(f[1]).readAsBytesSync()));
    helv = PdfFont.helvetica(doc);
    helvBold = PdfFont.helveticaBold(doc);
    PdfInfo(
      doc,
      title: (data['nome'] ?? '').trim().isEmpty ? 'Scheda PNG' : data['nome']!.trim(),
    ); // si registra da solo nel documento
  }

  final Map<String, String> data;
  final doc = PdfDocument();
  late final PdfFont serif, black, helv, helvBold;
  late PdfPage page;
  late PdfGraphics g;

  double width(String s, PdfFont font, double size) => font.stringMetrics(s).advanceWidth * size;

  /// Testo centrato con spaziatura lettere.
  double spaced(double cx, double y, String text, PdfFont font, double size, double cs) {
    final tw = width(text, font, size) + cs * (text.length - 1);
    g.drawString(font, size, text, cx - tw / 2, y, charSpace: cs);
    return tw;
  }

  // ---------- ornamenti ----------
  void spiral(double x, double y, double r, {double a0 = 0, double turns = 1.6, bool ccw = true}) {
    const n = 40;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final ang = a0 + (ccw ? 1 : -1) * t * turns * 2 * math.pi;
      final rr = r * (1 - .85 * t);
      final px = x + rr * math.cos(ang), py = y + rr * math.sin(ang);
      i == 0 ? g.moveTo(px, py) : g.lineTo(px, py);
    }
    g.strokePath();
  }

  void leaf(double x, double y, double len, double angle) {
    final a = angle * math.pi / 180, c = math.cos(a), s = math.sin(a);
    (double, double) p(double u, double v) => (x + u * c - v * s, y + u * s + v * c);
    void curve((double, double) a, (double, double) b, (double, double) e) =>
        g.curveTo(a.$1, a.$2, b.$1, b.$2, e.$1, e.$2);
    g.moveTo(x, y);
    curve(p(len * .3, len * .32), p(len * .8, len * .22), p(len, 0));
    curve(p(len * .8, -len * .22), p(len * .3, -len * .32), p(0, 0));
    g.fillAndStrokePath();
  }

  /// Linea decorativa orizzontale con foglioline alternate e ricci alle estremità.
  void vine(double x1, double x2, double y, {double step = 24, double leafLen = 7}) {
    g.setLineWidth(.8);
    g.moveTo(x1, y);
    final n = math.max(2, (x2 - x1) ~/ 4);
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      g.lineTo(x1 + (x2 - x1) * t, y + 1.2 * math.sin(t * math.pi * (x2 - x1) / step));
    }
    g.strokePath();
    var x = x1 + step * .6;
    for (var k = 0; x < x2 - step * .5; k++, x += step) {
      leaf(x, y, leafLen, k.isEven ? 35 : -35);
    }
    spiral(x1 - 2, y + 4, 5, a0: -math.pi / 2, ccw: false);
    spiral(x2 + 2, y + 4, 5, a0: -math.pi / 2);
  }

  /// Riccio d'angolo; sx, sy = direzione verso l'interno (±1).
  void corner(double x, double y, double sx, double sy) {
    g.setLineWidth(.9);
    g.moveTo(x, y + sy * 26);
    g.curveTo(x, y + sy * 8, x + sx * 8, y, x + sx * 26, y);
    g.strokePath();
    spiral(x + sx * 17, y + sy * 17, 8, a0: math.atan2(-sy, -sx), ccw: sx * sy < 0);
    final a = math.atan2(sy, sx) * 180 / math.pi;
    leaf(x + sx * 6, y + sy * 6, 8, a);
    leaf(x + sx * 23, y + sy * 4, 6, a + 30 * sx * sy);
    leaf(x + sx * 4, y + sy * 23, 6, a - 30 * sx * sy);
  }

  void shield(double cx, double cy, double s) {
    g.moveTo(cx - s, cy + s);
    g.lineTo(cx + s, cy + s);
    g.curveTo(cx + s, cy - s * .2, cx + s * .6, cy - s * .9, cx, cy - s * 1.2);
    g.curveTo(cx - s * .6, cy - s * .9, cx - s, cy - s * .2, cx - s, cy + s);
    g.closePath();
  }

  void heart(double cx, double cy, double s) {
    g.moveTo(cx, cy - s);
    g.curveTo(cx - s * 1.7, cy + s * .1, cx - s * .9, cy + s * 1.35, cx, cy + s * .45);
    g.curveTo(cx + s * .9, cy + s * 1.35, cx + s * 1.7, cy + s * .1, cx, cy - s);
    g.closePath();
  }

  /// Etichetta in un cartiglio centrato in (cx, cy), oppure con bordo sinistro in [left].
  void banner(double cx, double cy, String text, {double size = 7.5, bool bold = false, double? left}) {
    final font = bold ? black : serif;
    final tw = width(text, font, size) + .8 * (text.length - 1);
    final w = tw + 18, h = size + 7;
    if (left != null) cx = left + w / 2;
    g.setFillColor(_paper);
    g.setLineWidth(.7);
    g.drawRRect(cx - w / 2, cy - h / 2, w, h, h / 2, h / 2);
    g.fillAndStrokePath();
    spiral(cx - w / 2 - 3, cy, 4, ccw: false);
    spiral(cx + w / 2 + 3, cy, 4, a0: math.pi);
    g.setFillColor(_ink);
    spaced(cx, cy - size * .35, text, font, size, .8);
  }

  // ---------- riquadri + campi ----------
  void box(double x, double yTop, double w, double h, {String? label, double labelSize = 7.5}) {
    final y = _t(yTop + h);
    g.setFillColor(_box);
    g.setLineWidth(1);
    g.drawRRect(x, y, w, h, 7, 7);
    g.fillAndStrokePath();
    g.setLineWidth(.4);
    g.drawRRect(x + 2.5, y + 2.5, w - 5, h - 5, 5, 5);
    g.strokePath();
    g.setFillColor(_ink);
    if (label != null) banner(0, _t(yTop), label, size: labelSize, left: x + 12);
  }

  void textField(
    String name,
    double x,
    double y,
    double w,
    double h,
    double size, {
    bool multiline = false,
    bool center = false,
    bool bold = false,
  }) {
    PdfAnnot(
      page,
      PdfTextField(
        rect: PdfRect(x, y, w, h),
        fieldName: name,
        alternateName: labels[name],
        font: bold ? helvBold : helv,
        fontSize: size,
        textColor: _ink,
        fieldFlags: multiline ? {PdfFieldFlags.multiline} : null,
        textAlign: center ? PdfTextFieldAlign.center : null,
      ),
    );
  }

  /// A capo sugli spazi, come simpleSplit di reportlab: le parole troppo lunghe non vengono spezzate.
  List<String> wrap(String text, double maxW, double size) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final t = line.isEmpty ? word : '$line $word';
      if (line.isNotEmpty && width(t, serif, size) > maxW) {
        lines.add(line);
        line = word;
      } else {
        line = t;
      }
    }
    return [...lines, line];
  }

  /// Campo: testo fisso se compilato, campo modulo se vuoto.
  void field(
    String name,
    double x,
    double yTop,
    double w,
    double h, {
    double size = 10,
    bool multiline = false,
    double topPad = 9,
  }) {
    final value = (data[name] ?? '').trim();
    final fx = x + 5, fy = _t(yTop + h) + 5, fw = w - 10, fh = h - 5 - topPad;
    if (value.isEmpty) return textField(name, fx, fy, fw, fh, size, multiline: multiline);
    g.setFillColor(_ink);
    if (!multiline) return g.drawString(serif, size, value, fx + 2, fy + (fh - size * .7) / 2, charSpace: 0);
    var y = fy + fh - size;
    for (final para in value.split('\n')) {
      for (final line in wrap(para, fw - 4, size)) {
        if (y < fy) return;
        g.drawString(serif, size, line, fx + 2, y, charSpace: 0);
        y -= size * 1.25;
      }
    }
  }

  void fbox(
    String name,
    double x,
    double yTop,
    double w,
    double h, {
    double size = 9,
    bool multiline = true,
    double labelSize = 7.5,
  }) {
    box(x, yTop, w, h, label: labels[name], labelSize: labelSize);
    field(name, x, yTop, w, h, size: size, multiline: multiline);
  }

  /// Riquadro con simbolo (scudo/cuore) a sinistra e campo numerico a destra.
  void iconBox(String name, double x, double yTop, double w, double h, void Function(double, double, double) icon) {
    box(x, yTop, w, h, label: labels[name], labelSize: 6.5);
    final cx = x + 20, cy = _t(yTop + h / 2) - 3;
    g.setFillColor(_paper);
    g.setLineWidth(1);
    icon(cx, cy, 11);
    g.fillAndStrokePath();
    g.setLineWidth(.4);
    icon(cx, cy, 8);
    g.strokePath();
    g.setFillColor(_ink);
    field(name, x + 32, yTop, w - 32, h, size: 16, topPad: 11);
  }

  void statRing(String name, double cx, double cyTop, double r, {double size = 16}) {
    final cy = _t(cyTop);
    g.setFillColor(_box);
    g.setLineWidth(1);
    g.drawEllipse(cx, cy, r, r);
    g.fillAndStrokePath();
    g.setLineWidth(.5);
    g.drawEllipse(cx, cy, r - 3, r - 3);
    g.strokePath();
    g.setFillColor(_ink);
    banner(cx, _t(cyTop - r), labels[name]!, size: 6.5);
    final value = (data[name] ?? '').trim();
    if (value.isNotEmpty) {
      return g.drawString(black, size, value, cx - width(value, black, size) / 2, cy - size * .35, charSpace: 0);
    }
    final s = r * 1.3;
    textField(name, cx - s / 2, cy - s / 2, s, s, size, center: true, bold: true);
  }

  void portraitBox(Portrait? img) {
    box(_px, _py, _pw, _ph);
    if (img != null) {
      final x = _px + 4, y = _t(_py + _ph) + 4, w = _pw - 8, h = _ph - 8;
      g.saveContext();
      g.drawRRect(x, y, w, h, 4, 4);
      g.clipPath();
      g.drawImage(PdfImage(doc, image: img.rgba, width: img.width, height: img.height), x, y, w, h);
      g.restoreContext();
    }
    banner(0, _t(_py), 'RITRATTO', left: _px + 12); // sopra l'immagine
  }

  void frame(String title) {
    page = PdfPage(doc, pageFormat: PdfPageFormat.a4);
    g = page.getGraphics();
    g.setFillColor(_paper);
    g.drawRect(0, 0, _w, _h);
    g.fillPath();
    g.setStrokeColor(_ink);
    g.setFillColor(_ink);
    g.setLineWidth(1.2);
    g.drawRRect(_m, _m, _w - 2 * _m, _h - 2 * _m, 10, 10);
    g.strokePath();
    g.setLineWidth(.4);
    g.drawRRect(_m + 4, _m + 4, _w - 2 * _m - 8, _h - 2 * _m - 8, 7, 7);
    g.strokePath();
    for (final (sx, x) in [(1.0, _m + 6), (-1.0, _w - _m - 6)]) {
      for (final (sy, y) in [(1.0, _m + 6), (-1.0, _h - _m - 6)]) {
        corner(x, y, sx, sy);
      }
    }
    final tw = spaced(_w / 2, _t(56), title, black, 24, 2);
    vine(70, _w / 2 - tw / 2 - 18, _t(50));
    vine(_w / 2 + tw / 2 + 18, _w - 70, _t(50));
  }

  void footer(int n) {
    final text = 'Scheda compilabile · pagina $n di 2';
    g.setFillColor(_ink);
    g.drawString(serif, 7, text, _w / 2 - width(text, serif, 7) / 2, 17, charSpace: 0);
  }

  void page1(Portrait? portrait) {
    frame('SCHEDA PNG');
    fbox('nome', _l, 80, 303, 44, size: 14, multiline: false);
    portraitBox(portrait);
    fbox('classe_livello', _l, 132, 146, 40, size: 10, multiline: false);
    fbox('tipo_taglia', 199, 132, 146, 40, size: 10, multiline: false);
    fbox('occupazione_storia', _l, 181, 303, 40);
    fbox('aspetto', _l, 230, 303, 34);
    var y = 281.0;
    for (final (a, b) in [('dote', 'ideale'), ('modi_fare', 'legame'), ('interazione', 'difetti_segreti')]) {
      fbox(a, _l, y, _colW, 36);
      fbox(b, _l + _colW + _g, y, _colW, 36);
      y += 44;
    }
    fbox('conoscenze', _l, y, _r - _l, 36);
    // statistiche
    vine(_l + 10, _w / 2 - 60, _t(466));
    vine(_w / 2 + 60, _r - 10, _t(466));
    banner(_w / 2, _t(466), 'STATISTICHE', size: 9, bold: true);
    const sp = (_r - _l) / 6;
    const abilities = ['forza', 'destrezza', 'costituzione', 'intelligenza', 'saggezza', 'carisma'];
    for (var i = 0; i < 6; i++) {
      statRing(abilities[i], _l + sp * (i + .5), 513, 29);
    }
    iconBox('ca', _l, 558, 112, 46, shield);
    iconBox('pf', _l + 122, 558, 112, 46, heart);
    fbox('velocita', _r - 84, 558, 84, 46, size: 14, multiline: false, labelSize: 6.5);
    fbox('armatura_fonte', _l, 618, _r - _l, 30, multiline: false);
    fbox('tiri_salvezza', _l, 662, _r - _l, 30, multiline: false);
    fbox('abilita', _l, 706, _r - _l, 30, multiline: false);
    fbox('sensi', _l, 750, _colW, 30, multiline: false);
    fbox('linguaggi', _l + _colW + _g, 750, _colW, 30, multiline: false);
    footer(1);
  }

  void page2() {
    frame('CAPACITÀ E AZIONI');
    fbox('azioni', _l, 92, _colW, 288);
    fbox('incantesimi_giornalieri', _l + _colW + _g, 92, _colW, 288);
    fbox('capacita_passive', _l, 396, _colW, 210);
    fbox('equipaggiamento', _l + _colW + _g, 396, _colW, 210);
    fbox('note', _l, 622, _r - _l, 158);
    footer(2);
  }
}
