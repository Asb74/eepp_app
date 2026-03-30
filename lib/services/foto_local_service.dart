import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sync_queue_service.dart';

String limpiarNombre(String input) {
  const caracteresInvalidos = <String>[
    '<',
    '>',
    ':',
    '"',
    '/',
    '\\',
    '|',
    '?',
    '*',
    '\'',
    '`',
  ];

  for (final c in caracteresInvalidos) {
    input = input.replaceAll(c, '_');
  }

  return input.replaceAll(RegExp(r'\s+'), '_');
}

Future<void> guardarFotoLocal({
  required File imagen,
  required String idMuestra,
  required String pantalla,
  required String boleta,
  required String rutaDestino,
  required String filename,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final subdir = Directory('${dir.path}/fotos_pendientes');
  if (!await subdir.exists()) await subdir.create(recursive: true);

  final localFilename = limpiarNombre(filename);
  final rutaImagen = p.join(subdir.path, localFilename);

  await imagen.copy(rutaImagen);

  await SyncQueueService.instance.add(<String, dynamic>{
    'type': 'upload_foto',
    'localPath': rutaImagen,
    'idMuestra': idMuestra,
    'pantalla': limpiarNombre(pantalla),
    'boleta': limpiarNombre(boleta),
    'rutaDestino': limpiarNombre(rutaDestino),
    'filename': localFilename,
  });
}
