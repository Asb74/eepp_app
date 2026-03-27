import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> subirFotosPendientes() async {
  final dir = await getApplicationDocumentsDirectory();
  final subdir = Directory('${dir.path}/fotos_pendientes');

  if (!await subdir.exists()) return;

  // 🔁 Recuperar URL del servidor desde Firestore
  final urlDoc = await FirebaseFirestore.instance
      .collection('ServidorFotos')
      .doc('url_actual')
      .get();

  final urlServidor = urlDoc.data()?['url'];
  if (urlServidor == null || urlServidor.isEmpty) {
    print('❌ No se pudo recuperar la URL del servidor desde Firestore.');
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

      final uri = Uri.parse('$urlServidor/upload');

      final request = http.MultipartRequest('POST', uri)
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
        print('❌ Error al subir: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Excepción al subir foto pendiente: $e');
    }
  }
}
