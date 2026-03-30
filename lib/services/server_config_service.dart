import 'package:cloud_firestore/cloud_firestore.dart';

class ServerConfig {
  final String url;
  final String apiKey;
  final String rutaServidor;

  const ServerConfig({
    required this.url,
    required this.apiKey,
    required this.rutaServidor,
  });
}

Future<ServerConfig> getServerConfig() async {
  try {
    print('🔍 Cargando configuración servidor...');

    final configDoc = await FirebaseFirestore.instance
        .collection('ServidorFotos')
        .doc('configSalida')
        .get();

    if (!configDoc.exists) {
      throw Exception(
        'No existe el documento ServidorFotos/configSalida en Firestore.',
      );
    }

    final data = configDoc.data();
    if (data == null) {
      throw Exception(
        'El documento ServidorFotos/configSalida no contiene datos (data() == null).',
      );
    }

    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw Exception(
        'Configuración inválida: el campo obligatorio "url" está vacío o no existe.',
      );
    }

    final apiKey = (data['api_key'] ?? '').toString().trim();
    if (apiKey.isEmpty) {
      throw Exception(
        'Configuración inválida: el campo obligatorio "api_key" está vacío o no existe.',
      );
    }

    final rutaServidor = (data['rutaservidor'] ?? '').toString().trim();
    if (rutaServidor.isEmpty) {
      throw Exception(
        'Configuración inválida: el campo obligatorio "rutaservidor" está vacío o no existe.',
      );
    }

    print('✅ Config cargada correctamente');

    return ServerConfig(
      url: url,
      apiKey: apiKey,
      rutaServidor: rutaServidor,
    );
  } catch (e) {
    print('❌ Error config: $e');
    throw Exception('Error al cargar configuración de servidor: $e');
  }
}
