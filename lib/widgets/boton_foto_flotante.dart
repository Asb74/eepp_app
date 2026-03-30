import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:harvestsync/usuario_actual.dart' as usuario;
import 'package:harvestsync/util/conexion_util.dart';
import 'package:harvestsync/services/foto_local_service.dart';
import 'package:harvestsync/services/server_config_service.dart';

class BotonFotoFlotante extends StatelessWidget {
  final String? idMuestra;
  final String pantalla;
  final String cultivo;

  const BotonFotoFlotante({
    super.key,
    required this.idMuestra,
    required this.pantalla,
    required this.cultivo,
  });

  Future<void> _tomarYGuardarFoto(BuildContext context) async {
    if (idMuestra == null || idMuestra!.isEmpty || cultivo.isEmpty) return;

    try {
      final picker = ImagePicker();
      final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (imagen == null) return;

      // 🔌 Verificar conectividad
      final conectado = await hayConexion();
      if (!conectado) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📷 Sin conexión. Guardando foto localmente...')),
          );
        }

        // 🔽 Importar la función
        // Asegúrate de tener esta línea al inicio del archivo:
        // import 'package:harvestsync/services/foto_local_service.dart';

        final file = File(imagen.path);

        final muestraDoc = await FirebaseFirestore.instance
            .collection('Muestras')
            .doc(idMuestra)
            .get();
        final data = muestraDoc.data() ?? {};
        final boleta = data['Boleta'] ?? '';

        final nombrePlantilla = 'Plantillas$pantalla';
        final docPlantilla = await FirebaseFirestore.instance
            .collection(nombrePlantilla)
            .doc(cultivo)
            .get();
        final tituloPantalla = docPlantilla.data()?['Titulo'] ?? pantalla;

        await guardarFotoLocal(
          imagen: file,
          idMuestra: idMuestra!,
          pantalla: tituloPantalla,
          boleta: boleta,
          rutaDestino: usuario.rutaServidor,
        );

        return;
      }
      final serverConfig = await getServerConfig();

      final muestraDoc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(idMuestra)
          .get();
      final data = muestraDoc.data() ?? {};
      final boleta = data['Boleta'] ?? '';

      final nombrePlantilla = 'Plantillas$pantalla';
      final docPlantilla = await FirebaseFirestore.instance
          .collection(nombrePlantilla)
          .doc(cultivo)
          .get();
      final tituloPantalla = docPlantilla.data()?['Titulo'] ?? pantalla;

      final nombre = "${idMuestra!}*${tituloPantalla}*${DateTime.now().millisecondsSinceEpoch}.jpg";

      final uri = Uri.parse('${serverConfig.url}/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['X-API-KEY'] = serverConfig.apiKey
        ..fields['idMuestra'] = idMuestra!
        ..fields['pantalla'] = tituloPantalla
        ..fields['boleta'] = boleta
        ..fields['rutaDestino'] = serverConfig.rutaServidor.isNotEmpty
            ? serverConfig.rutaServidor
            : usuario.rutaServidor; // 💡 Aquí se pasa la ruta

      final file = File(imagen.path);
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: nombre,
      ));

      final response = await request.send();

      if (response.statusCode == 200) {
        await FirebaseFirestore.instance.collection('Fotos').add({
          'ruta_local': nombre,
          'idMuestra': idMuestra!,
          'pantalla': tituloPantalla,
          'boleta': boleta,
          'timestamp': Timestamp.now(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('📸 Foto enviada correctamente: $nombre')),
          );
        }
      } else {
        throw 'Error al subir la foto (código ${response.statusCode})';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (idMuestra == null || idMuestra!.isEmpty || cultivo.isEmpty) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      heroTag: 'foto_$pantalla',
      onPressed: () => _tomarYGuardarFoto(context),
      tooltip: 'Tomar foto',
      child: const Icon(Icons.camera_alt),
    );
  }
}
