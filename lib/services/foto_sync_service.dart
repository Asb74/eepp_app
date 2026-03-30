import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'server_config_service.dart';

class FotoSyncService {
  FotoSyncService._();

  static final FotoSyncService instance = FotoSyncService._();

  Future<bool> syncQueuedPhoto(Map<String, dynamic> item) async {
    final localPath = item['localPath']?.toString() ?? '';
    final idMuestra = item['idMuestra']?.toString() ?? '';
    final pantalla = item['pantalla']?.toString() ?? '';
    final boleta = item['boleta']?.toString() ?? '';
    final rutaDestino = item['rutaDestino']?.toString() ?? '';
    final filename = item['filename']?.toString() ?? '';

    if (localPath.isEmpty || idMuestra.isEmpty || filename.isEmpty) {
      return false;
    }

    final imageFile = File(localPath);
    if (!await imageFile.exists()) {
      return true;
    }

    final serverConfig = await getServerConfig();
    final uri = Uri.parse('${serverConfig.url}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['X-API-KEY'] = serverConfig.apiKey
      ..fields['idMuestra'] = idMuestra
      ..fields['pantalla'] = pantalla
      ..fields['boleta'] = boleta
      ..fields['rutaDestino'] = rutaDestino
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        localPath,
        filename: filename,
      ));

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Upload foto falló ${response.statusCode}: $body');
    }

    final responseText = await response.stream.bytesToString();
    final data = _tryDecode(responseText);
    final rutaLocal = data['filename']?.toString().trim().isNotEmpty == true
        ? data['filename'].toString().trim()
        : filename;

    await FirebaseFirestore.instance.collection('Fotos').add(<String, dynamic>{
      'ruta_local': rutaLocal,
      'idMuestra': idMuestra,
      'pantalla': pantalla,
      'boleta': boleta,
      'timestamp': Timestamp.now(),
    });

    await imageFile.delete();
    return true;
  }

  Map<String, dynamic> _tryDecode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}

Future<void> subirFotosPendientes() async {
  // Compatibilidad con flujo antiguo: la sincronización real la hace OfflineSyncService.
}
