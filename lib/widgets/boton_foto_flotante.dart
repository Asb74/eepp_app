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

class BotonFotoFlotante extends StatefulWidget {
  final String? idMuestra;
  final String pantalla;
  final String cultivo;

  const BotonFotoFlotante({
    super.key,
    required this.idMuestra,
    required this.pantalla,
    required this.cultivo,
  });

  @override
  State<BotonFotoFlotante> createState() => _BotonFotoFlotanteState();
}

class _BotonFotoFlotanteState extends State<BotonFotoFlotante> {
  static final Set<String> _rutasProcesadas = <String>{};

  Future<void> _tomarYGuardarFoto(BuildContext context) async {
    if (widget.idMuestra == null || widget.idMuestra!.isEmpty || widget.cultivo.isEmpty) return;

    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (imagen == null) return;

    final file = File(imagen.path);
    await procesarImagen(context, file);
  }

  Future<void> procesarImagen(BuildContext context, File file) async {
    if (widget.idMuestra == null || widget.idMuestra!.isEmpty || widget.cultivo.isEmpty) return;

    if (_rutasProcesadas.contains(file.path)) return;
    _rutasProcesadas.add(file.path);

    String boleta = '';
    String tituloPantalla = widget.pantalla;
    String nombreArchivo =
        '${widget.idMuestra!}_${limpiarNombre(widget.pantalla)}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final muestraDoc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .get();
      final data = muestraDoc.data() ?? <String, dynamic>{};
      boleta = data['Boleta']?.toString() ?? '';

      final nombrePlantilla = 'Plantillas${widget.pantalla}';
      final docPlantilla = await FirebaseFirestore.instance
          .collection(nombrePlantilla)
          .doc(widget.cultivo)
          .get();
      tituloPantalla = docPlantilla.data()?['Titulo']?.toString() ?? widget.pantalla;

      nombreArchivo =
          '${widget.idMuestra!}_${limpiarNombre(tituloPantalla)}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await ConnectivityService.instance.refresh();
      if (ConnectivityService.instance.currentStatus != ConnectionStatus.online) {
        await guardarFotoLocal(
          imagen: file,
          idMuestra: widget.idMuestra!,
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
        ..fields['idMuestra'] = widget.idMuestra!
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
            'idMuestra': widget.idMuestra!,
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
          idMuestra: widget.idMuestra!,
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
      await guardarFotoLocal(
        imagen: file,
        idMuestra: widget.idMuestra!,
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
  }

  Future<void> recuperarImagenPerdida(BuildContext context) async {
    try {
      final lostData = await ImagePicker().retrieveLostData();
      if (lostData.isEmpty || lostData.file == null) return;

      final file = File(lostData.file!.path);
      await procesarImagen(context, file);
    } catch (_) {
      // Manejo silencioso para no interrumpir la UI.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      recuperarImagenPerdida(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idMuestra == null || widget.idMuestra!.isEmpty || widget.cultivo.isEmpty) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      heroTag: 'foto_${widget.pantalla}',
      onPressed: () => _tomarYGuardarFoto(context),
      tooltip: 'Tomar foto',
      child: const Icon(Icons.camera_alt),
    );
  }
}
