import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:harvestsync/services/server_config_service.dart';

Future<void> subirFotosPendientes() async {
  final dir = await getApplicationDocumentsDirectory();
  final subdir = Directory('${dir.path}/fotos_pendientes');

  if (!await subdir.exists()) return;

  ServerConfig serverConfig;
  try {
    serverConfig = await getServerConfig();
  } catch (e) {
    print('❌ No se pudo cargar la configuración del servidor para sincronizar: $e');
    return;
  }

  final archivos = subdir
      .listSync()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  for (final archivoJson in archivos) {
    try {
      final meta = jsonDecode(await File(archivoJson.path).readAsString());

      final ruta = meta['ruta'];
      final idMuestra = meta['idMuestra'];
      final pantalla = meta['pantalla'];
      final boleta = meta['boleta'];
      final rutaDestino = meta['rutaDestino'];

      final imagen = File(ruta);
      if (!await imagen.exists()) continue;

      final uri = Uri.parse('${serverConfig.url}/upload');

      final request = http.MultipartRequest('POST', uri)
        ..headers['X-API-KEY'] = serverConfig.apiKey
        ..fields['idMuestra'] = idMuestra
        ..fields['pantalla'] = pantalla
        ..fields['boleta'] = boleta
        ..fields['rutaDestino'] = rutaDestino
        ..files.add(await http.MultipartFile.fromPath('file', ruta));

      final response = await request.send();

      if (response.statusCode == 200) {
        await imagen.delete();
        await File(archivoJson.path).delete();
      } else {
        print('❌ Error al subir foto pendiente: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Excepción al subir foto pendiente: $e');
    }
  }
}
