import 'dart:io';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> compartilharTexto(String texto, {String? assunto}) async {
    await SharePlus.instance.share(ShareParams(text: texto, subject: assunto));
  }

  Future<void> copiar(String texto) => Clipboard.setData(ClipboardData(text: texto));

  /// Captura um widget envolvido por RepaintBoundary(key: chave) como PNG e compartilha.
  Future<void> compartilharImagem(GlobalKey chave, {required String texto, String nomeArquivo = 'radar_politico.png'}) async {
    final ctx = chave.currentContext;
    if (ctx == null) throw StateError('Imagem indisponível');
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final ui.Image img = await boundary.toImage(pixelRatio: 3);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Falha ao gerar imagem');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nomeArquivo');
    await f.writeAsBytes(bytes.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')], text: texto));
  }
}
