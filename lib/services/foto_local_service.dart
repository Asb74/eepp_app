import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

String limpiarNombre(String input) {
  final caracteresInvalidos = ['<', '>', ':', '"', '/', '\\', '|', '?', '*', '\'', '`'];
  for (var c in caracteresInvalidos) {
    input = input.replaceAll(c, '_');
  }
  return input;
}

Future<void> guardarFotoLocal({
  required File imagen,
  required String idMuestra,
  required String pantalla,
  required String boleta,
  required String rutaDestino,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final subdir = Directory('${dir.path}/fotos_pendientes');
  if (!await subdir.exists()) await subdir.create();

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final nombreBase = '$timestamp';

  final pantallaSegura = limpiarNombre(pantalla);
  final boletaSegura = limpiarNombre(boleta);
  final rutaDestinoSegura = limpiarNombre(rutaDestino);

  final rutaImagen = '${subdir.path}/$nombreBase.jpg';
  final rutaMetadata = '${subdir.path}/$nombreBase.json';

  await imagen.copy(rutaImagen);

  final metadata = {
    'ruta': rutaImagen,
    'idMuestra': idMuestra,
    'pantalla': pantallaSegura,
    'boleta': boletaSegura,
    'rutaDestino': rutaDestinoSegura,
  };

  final archivoMeta = File(rutaMetadata);
  await archivoMeta.writeAsString(jsonEncode(metadata));
}
