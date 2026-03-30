import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/foto_local_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';
import 'package:harvestsync/services/server_config_service.dart';
import 'package:harvestsync/usuario_actual.dart' as usuario;

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

    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (imagen == null) return;

    final file = File(imagen.path);

    try {
      final muestraDoc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(idMuestra)
          .get();
      final data = muestraDoc.data() ?? <String, dynamic>{};
      final boleta = data['Boleta']?.toString() ?? '';

      final nombrePlantilla = 'Plantillas$pantalla';
      final docPlantilla = await FirebaseFirestore.instance
          .collection(nombrePlantilla)
          .doc(cultivo)
          .get();
      final tituloPantalla = docPlantilla.data()?['Titulo']?.toString() ?? pantalla;

      final nombreArchivo =
          '${idMuestra!}_${limpiarNombre(tituloPantalla)}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (ConnectivityService.instance.currentStatus != ConnectionStatus.online) {
        await guardarFotoLocal(
          imagen: file,
          idMuestra: idMuestra!,
          pantalla: tituloPantalla,
          boleta: boleta,
          rutaDestino: usuario.rutaServidor,
          filename: nombreArchivo,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado en local')),
          );
        }
        return;
      }

      final serverConfig = await getServerConfig();
      final uri = Uri.parse('${serverConfig.url}/upload');

      final request = http.MultipartRequest('POST', uri)
        ..headers['X-API-KEY'] = serverConfig.apiKey
        ..fields['idMuestra'] = idMuestra!
        ..fields['pantalla'] = tituloPantalla
        ..fields['boleta'] = boleta
        ..fields['rutaDestino'] =
            serverConfig.rutaServidor.isNotEmpty ? serverConfig.rutaServidor : usuario.rutaServidor
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: nombreArchivo,
        ));

      final response = await request.send();

      if (response.statusCode == 200) {
        await OfflineWriteService.addFirestoreOrQueue(
          collection: 'Fotos',
          payload: <String, dynamic>{
            'ruta_local': nombreArchivo,
            'idMuestra': idMuestra!,
            'pantalla': tituloPantalla,
            'boleta': boleta,
            'timestamp': Timestamp.now(),
          },
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('📸 Foto enviada correctamente: $nombreArchivo')),
          );
        }
      } else {
        await guardarFotoLocal(
          imagen: file,
          idMuestra: idMuestra!,
          pantalla: tituloPantalla,
          boleta: boleta,
          rutaDestino: usuario.rutaServidor,
          filename: nombreArchivo,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado en local')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado en local')),
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
