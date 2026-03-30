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
  final configDoc = await FirebaseFirestore.instance
      .collection('ServidorFotos')
      .doc('configSalida')
      .get();

  final data = configDoc.data();
  if (data == null) {
    throw Exception('No existe el documento ServidorFotos/configSalida.');
  }

  final url = (data['url'] ?? '').toString().trim();
  if (url.isEmpty) {
    throw Exception('Configuración inválida: el campo "url" está vacío en configSalida.');
  }

  final apiKeyRaw = data['api_key'];
  if (apiKeyRaw == null) {
    print('❌ Configuración inválida: falta el campo "api_key" en ServidorFotos/configSalida.');
    throw Exception('Configuración inválida: falta "api_key" en configSalida.');
  }

  final apiKey = apiKeyRaw.toString();
  final rutaServidor = (data['rutaservidor'] ?? '').toString();

  return ServerConfig(
    url: url,
    apiKey: apiKey,
    rutaServidor: rutaServidor,
  );
}
