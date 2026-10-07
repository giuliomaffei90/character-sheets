// Editor schede PNG: compila i campi, carica il ritratto, esporta il PDF. Salvataggio automatico.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sheet.dart';

final dataDir = Directory('${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/SchedePNG');
const vw = 240.0; // riquadro ritratto, stesso rapporto del PDF
final vh = (vw * portraitAspect).roundToDouble();
const exportW = 1000; // larghezza in px del ritratto esportato
const saves = ['Forza', 'Destrezza', 'Costituzione', 'Intelligenza', 'Saggezza', 'Carisma'];
const skills = [
  'Acrobazia',
  'Addestrare Animali',
  'Arcano',
  'Atletica',
  'Furtività',
  'Indagare',
  'Inganno',
  'Intimidire',
  'Intrattenere',
  'Intuizione',
  'Medicina',
  'Natura',
  'Percezione',
  'Persuasione',
  'Rapidità di Mano',
  'Religione',
  'Sopravvivenza',
  'Storia',
];
const abilities = ['forza', 'destrezza', 'costituzione', 'intelligenza', 'saggezza', 'carisma'];

const ink = Color(0xFF6B3A2B);

String title(String k) {
  final l = labels[k]!;
  return l.length > 3 ? l[0] + l.substring(1).toLowerCase() : l;
}

String fieldOf(Map rec, String k) => '${(rec['fields'] as Map)[k] ?? ''}';

/// Rettangolo (px immagine) visibile nel riquadro, con il centro riportato dentro i limiti.
({Rect rect, double cx, double cy}) region(Size img, double zoom, double cx, double cy) {
  final s = math.max(vw / img.width, vh / img.height) * zoom;
  final rw = vw / s, rh = vh / s;
  cx = math.min(math.max(cx, rw / 2 / img.width), 1 - rw / 2 / img.width);
  cy = math.min(math.max(cy, rh / 2 / img.height), 1 - rh / 2 / img.height);
  return (
    rect: Rect.fromCenter(center: Offset(cx * img.width, cy * img.height), width: rw, height: rh),
    cx: cx,
    cy: cy,
  );
}

void main() =>
    runApp(MaterialApp(title: 'Schede PNG', debugShowCheckedModeBanner: false, theme: theme(), home: const Home()));

/// Solo tema scuro, con i toni caldi dell'inchiostro della scheda.
ThemeData theme() {
  final cs = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final text = ThemeData(colorScheme: cs).textTheme;
  TextStyle serif(TextStyle? s) => s!.copyWith(fontFamily: 'Georgia', fontWeight: FontWeight.w600);
  final radius = BorderRadius.circular(10);
  return ThemeData(
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    textTheme: text.copyWith(
      headlineSmall: serif(text.headlineSmall),
      titleLarge: serif(text.titleLarge),
      titleMedium: serif(text.titleMedium),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: .6)),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedTileColor: cs.secondaryContainer,
      selectedColor: cs.onSecondaryContainer,
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ctrl = {for (final k in labels.keys) k: TextEditingController()};
  final focus = {'tiri_salvezza': FocusNode(), 'abilita': FocusNode()};
  final search = TextEditingController();
  final chars = <Map<String, dynamic>>[];
  String? id;
  ui.Image? img;
  String? imgFile; // nome del file in dataDir
  double zoom = 1, cx = .5, cy = .5, zoomStart = 1;
  bool loading = false; // niente salvataggi mentre si riempiono i campi

  @override
  void initState() {
    super.initState();
    dataDir.createSync(recursive: true);
    for (final f in dataDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      try {
        final rec = jsonDecode(f.readAsStringSync());
        if (rec is Map<String, dynamic> && rec['id'] is String && rec['fields'] is Map) chars.add(rec);
      } on FormatException {
        continue;
      }
    }
    for (final c in ctrl.values) {
      c.addListener(save);
    }
  }

  String nameOf(Map rec) => fieldOf(rec, 'nome').trim().isEmpty ? 'Senza nome' : fieldOf(rec, 'nome').trim();

  // ---------- dati ----------
  void save() {
    if (loading) return;
    final fields = {for (final e in ctrl.entries) e.key: e.value.text};
    if (id == null && imgFile == null && fields.values.every((v) => v.trim().isEmpty)) return;
    id ??= newId();
    final rec = <String, dynamic>{
      'id': id,
      'fields': fields,
      'image': imgFile,
      'zoom': zoom,
      'cx': cx,
      'cy': cy,
      'updated': DateTime.now().toIso8601String().substring(0, 19),
    };
    File('${dataDir.path}/$id.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rec));
    setState(
      () => chars
        ..removeWhere((c) => c['id'] == id)
        ..add(rec),
    );
  }

  String newId() => List.generate(8, (_) => math.Random.secure().nextInt(16).toRadixString(16)).join();

  Future<ui.Image?> decode(String path) async {
    try {
      return (await (await ui.instantiateImageCodec(await File(path).readAsBytes())).getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  void fill(Map rec) {
    loading = true;
    for (final e in ctrl.entries) {
      e.value.text = fieldOf(rec, e.key);
    }
    loading = false;
  }

  void newChar() {
    fill({'fields': {}});
    setState(() {
      id = imgFile = null;
      img = null;
      zoom = 1;
      cx = cy = .5;
    });
  }

  Future<void> open(Map rec) async {
    if (rec['id'] == id) return;
    fill(rec);
    final file = rec['image'] as String?;
    final image = file == null ? null : await decode('${dataDir.path}/$file');
    setState(() {
      id = rec['id'];
      img = image;
      imgFile = image == null ? null : file;
      zoom = (rec['zoom'] as num? ?? 1).toDouble();
      cx = (rec['cx'] as num? ?? .5).toDouble();
      cy = (rec['cy'] as num? ?? .5).toDouble();
    });
  }

  Future<void> delete() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(
          'Eliminare «${nameOf({
            'fields': {'nome': ctrl['nome']!.text},
          })}»?',
        ),
        content: const Text('Il personaggio e il suo ritratto verranno eliminati definitivamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final f in dataDir.listSync().whereType<File>().where((f) => f.uri.pathSegments.last.startsWith('$id.'))) {
      f.deleteSync();
    }
    chars.removeWhere((c) => c['id'] == id);
    newChar();
  }

  // ---------- ritratto ----------
  Future<void> pickImage() async {
    final x = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Immagini', extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif']),
      ],
    );
    if (x == null) return;
    final image = await decode(x.path);
    if (image == null) return snack('Immagine non valida: scegli un file PNG, JPG, WebP, BMP o GIF.');
    id ??= newId();
    final name = '$id.${x.path.split('.').last.toLowerCase()}';
    final dst = File('${dataDir.path}/$name');
    if (imgFile != null && imgFile != name) File('${dataDir.path}/$imgFile').deleteSync();
    if (File(x.path).absolute.path != dst.absolute.path) await File(x.path).copy(dst.path);
    imageCache.clear(); // le miniature nell'elenco usano lo stesso percorso
    setState(() {
      img = image;
      imgFile = name;
      zoom = 1;
      cx = cy = .5;
    });
    save();
  }

  void removeImage() {
    File('${dataDir.path}/$imgFile').deleteSync();
    setState(() {
      img = null;
      imgFile = null;
    });
    save();
  }

  /// Zoom e spostamento (in px del riquadro) del ritratto.
  void move(double z, Offset d) => setState(() {
    final size = Size(img!.width.toDouble(), img!.height.toDouble());
    zoom = z.clamp(1.0, 6.0);
    final s = math.max(vw / size.width, vh / size.height) * zoom;
    final r = region(size, zoom, cx - d.dx / s / size.width, cy - d.dy / s / size.height);
    cx = r.cx;
    cy = r.cy;
  });

  Future<Portrait?> portraitPixels() async {
    if (img == null) return null;
    final h = (exportW * vh / vw).round();
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
      img!,
      region(Size(img!.width.toDouble(), img!.height.toDouble()), zoom, cx, cy).rect,
      Rect.fromLTWH(0, 0, exportW.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final data = await (await rec.endRecording().toImage(exportW, h)).toByteData(format: ui.ImageByteFormat.rawRgba);
    return (rgba: data!.buffer.asUint8List(), width: exportW, height: h);
  }

  // ---------- azioni ----------
  Future<void> export() async {
    final nome = ctrl['nome']!.text.trim();
    final loc = await getSaveLocation(
      suggestedName: '${nome.isEmpty ? 'Scheda PNG' : nome}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (loc == null) return;
    final path = loc.path.toLowerCase().endsWith('.pdf') ? loc.path : '${loc.path}.pdf';
    try {
      final bytes = await buildSheet({for (final e in ctrl.entries) e.key: e.value.text}, await portraitPixels());
      await File(path).writeAsBytes(bytes);
    } catch (e) {
      return snack('Esportazione non riuscita: $e');
    }
    snack(
      'Esportato: ${File(path).uri.pathSegments.last}',
      action: SnackBarAction(
        label: 'Apri',
        onPressed: () => Process.run(Platform.isMacOS ? 'open' : 'explorer', [path]),
      ),
    );
  }

  void snack(String msg, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), action: action, behavior: SnackBarBehavior.floating, width: 440));

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final mac = Platform.isMacOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyN, meta: mac, control: !mac): newChar,
        SingleActivator(LogicalKeyboardKey.keyE, meta: mac, control: !mac): export,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              sidebar(),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    topBar(),
                    const Divider(height: 1),
                    Expanded(child: form()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sidebar() {
    final t = Theme.of(context), cs = t.colorScheme;
    final q = search.text.toLowerCase();
    final list =
        chars
            .where((c) => nameOf(c).toLowerCase().contains(q) || fieldOf(c, 'classe_livello').toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
    return Material(
      // Material, non Container: serve allo sfondo dei ListTile selezionati
      color: cs.surfaceContainerLow,
      child: SizedBox(
        width: 288,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Schede PNG', style: t.textTheme.titleLarge),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cerca per nome o classe',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonalIcon(
                onPressed: newChar,
                icon: const Icon(Icons.add),
                label: const Text('Nuovo personaggio'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'PERSONAGGI · ${chars.length}',
                style: t.textTheme.labelSmall!.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        q.isEmpty ? 'Nessun personaggio salvato.\nInizia a compilare la scheda.' : 'Nessun risultato.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      children: [
                        for (final c in list)
                          ListTile(
                            selected: c['id'] == id,
                            leading: avatar(c),
                            title: Text(nameOf(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: fieldOf(c, 'classe_livello').isEmpty
                                ? null
                                : Text(fieldOf(c, 'classe_livello'), maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => open(c),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget avatar(Map c) {
    final cs = Theme.of(context).colorScheme;
    final file = c['image'] as String?;
    final name = nameOf(c);
    return CircleAvatar(
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      foregroundImage: file == null ? null : ResizeImage(FileImage(File('${dataDir.path}/$file')), width: 96),
      onForegroundImageError: file == null ? null : (_, _) {},
      child: Text(name.characters.first.toUpperCase(), style: const TextStyle(fontFamily: 'Georgia')),
    );
  }

  Widget topBar() {
    final t = Theme.of(context), cs = t.colorScheme;
    final nome = ctrl['nome']!.text.trim();
    final key = Platform.isMacOS ? '⌘' : 'Ctrl+';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome.isEmpty ? (id == null ? 'Nuovo personaggio' : 'Senza nome') : nome,
                  style: t.textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      id == null ? Icons.edit_note : Icons.cloud_done_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      id == null ? 'Inizia a scrivere: la scheda si salva da sola' : 'Salvato automaticamente',
                      style: t.textTheme.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (id != null)
            IconButton(
              onPressed: delete,
              tooltip: 'Elimina personaggio',
              icon: Icon(Icons.delete_outline, color: cs.error),
            ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Esporta PDF (${key}E)',
            child: FilledButton.icon(
              onPressed: export,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Esporta PDF'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
        ],
      ),
    );
  }

  Widget form() => Scrollbar(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section(null, [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: gap([
                          field(
                            'nome',
                            style: Theme.of(context).textTheme.headlineSmall,
                            hint: 'Es. Brunilde la Fabbra',
                          ),
                          row([
                            field('classe_livello', hint: 'Es. Guerriero 5'),
                            field('tipo_taglia', hint: 'Es. Umanoide, Media'),
                          ]),
                          field('occupazione_storia', lines: 3),
                          field('aspetto', lines: 3),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 28),
                    portrait(),
                  ],
                ),
              ]),
              section('Personalità', [
                row([field('dote', lines: 2), field('ideale', lines: 2)]),
                row([field('modi_fare', lines: 2), field('legame', lines: 2)]),
                row([field('interazione', lines: 2), field('difetti_segreti', lines: 2)]),
                field('conoscenze', lines: 2),
              ]),
              section('Statistiche', [
                row([for (final k in abilities) ability(k)], spacing: 12),
                row(
                  [
                    field('ca', number: true, icon: Icons.shield_outlined),
                    field('pf', number: true, icon: Icons.favorite_outline),
                    field('velocita', number: true, icon: Icons.directions_run),
                    field('armatura_fonte', hint: 'Es. Cotta di maglia, scudo'),
                  ],
                  flex: [1, 1, 1, 3],
                ),
                field('tiri_salvezza', options: saves, hint: 'Scegli con ⊕ e scrivi il bonus, es. Saggezza +3'),
                field('abilita', options: skills, hint: 'Scegli con ⊕ e scrivi il bonus, es. Percezione +5'),
                row([field('sensi', hint: 'Es. Scurovisione 18 m'), field('linguaggi', hint: 'Es. Comune, Nanico')]),
              ]),
              section('Capacità e azioni', [
                row([field('azioni', lines: 8), field('incantesimi_giornalieri', lines: 8)]),
                row([field('capacita_passive', lines: 6), field('equipaggiamento', lines: 6)]),
                field('note', lines: 5),
              ]),
            ].expand((w) => [w, const SizedBox(height: 20)]).toList(),
          ),
        ),
      ),
    ),
  );

  List<Widget> gap(List<Widget> ws, [double h = 16]) => [
    for (final w in ws) ...[if (w != ws.first) SizedBox(height: h), w],
  ];

  Widget section(String? name, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name != null) ...[
            Row(
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
          ],
          ...gap(children),
        ],
      ),
    ),
  );

  Widget row(List<Widget> ws, {List<int>? flex, double spacing = 16}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < ws.length; i++) ...[
        if (i > 0) SizedBox(width: spacing),
        Expanded(flex: flex?[i] ?? 1, child: ws[i]),
      ],
    ],
  );

  Widget field(
    String k, {
    int lines = 1,
    bool number = false,
    IconData? icon,
    String? hint,
    TextStyle? style,
    List<String>? options,
  }) {
    final c = ctrl[k]!;
    return TextField(
      controller: c,
      focusNode: focus[k],
      minLines: lines,
      maxLines: lines == 1 ? 1 : null,
      keyboardType: lines > 1 ? TextInputType.multiline : null,
      textAlign: number ? TextAlign.center : TextAlign.start,
      style: style,
      decoration: InputDecoration(
        labelText: title(k),
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: options == null
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Aggiungi ${title(k).toLowerCase()}',
                itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o, child: Text(o))],
                onSelected: (o) {
                  c.text = c.text.trim().isEmpty ? '$o +' : '${c.text.trimRight()}, $o +';
                  c.selection = TextSelection.collapsed(offset: c.text.length);
                  focus[k]!.requestFocus();
                },
              ),
      ),
    );
  }

  /// Caratteristica con modificatore calcolato, es. 14 → +2.
  Widget ability(String k) {
    final t = Theme.of(context);
    final v = int.tryParse(ctrl[k]!.text.trim());
    final mod = v == null ? null : ((v - 10) / 2).floor();
    return Column(
      children: [
        TextField(
          controller: ctrl[k],
          textAlign: TextAlign.center,
          style: t.textTheme.headlineSmall,
          decoration: InputDecoration(labelText: labels[k], hintText: '10'),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          child: Text(
            mod == null ? '' : (mod >= 0 ? '+$mod' : '$mod'),
            style: t.textTheme.labelLarge!.copyWith(color: t.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget portrait() {
    final t = Theme.of(context), cs = t.colorScheme;
    final image = img;
    return SizedBox(
      width: vw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ritratto', style: t.textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: vh,
              child: image == null
                  ? Material(
                      color: cs.surfaceContainerHighest,
                      child: InkWell(
                        onTap: pickImage,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40, color: cs.primary),
                            const SizedBox(height: 8),
                            Text('Aggiungi un ritratto', style: t.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('PNG, JPG, WebP', style: t.textTheme.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    )
                  : MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Listener(
                        onPointerSignal: (e) {
                          if (e is! PointerScrollEvent) return;
                          GestureBinding.instance.pointerSignalResolver.register(e, (_) {
                            move(zoom * math.pow(1.1, -e.scrollDelta.dy / 40), Offset.zero);
                            save();
                          });
                        },
                        child: GestureDetector(
                          onScaleStart: (_) => zoomStart = zoom,
                          onScaleUpdate: (d) => move(zoomStart * d.scale, d.focalPointDelta),
                          onScaleEnd: (_) => save(),
                          child: CustomPaint(
                            size: Size(vw, vh),
                            painter: _PortraitPainter(
                              image,
                              region(Size(image.width.toDouble(), image.height.toDouble()), zoom, cx, cy).rect,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.zoom_out, size: 18, color: cs.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: zoom,
                  min: 1,
                  max: 6,
                  label: 'Zoom',
                  onChanged: image == null ? null : (v) => move(v, Offset.zero),
                  onChangeEnd: (_) => save(),
                ),
              ),
              Icon(Icons.zoom_in, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
          if (image != null)
            Text(
              'Trascina per spostare, rotella o pinch per lo zoom',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(image == null ? 'Scegli immagine' : 'Cambia'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
              if (image != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: removeImage,
                  tooltip: 'Rimuovi ritratto',
                  icon: const Icon(Icons.hide_image_outlined),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.img, this.src);

  final ui.Image img;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImageRect(img, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);

  @override
  bool shouldRepaint(_PortraitPainter old) => old.img != img || old.src != src;
}
