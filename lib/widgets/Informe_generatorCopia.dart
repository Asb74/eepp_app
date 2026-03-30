import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:harvestsync/usuario_actual.dart' as usuario;

class InformeGenerator {
  static Future<pw.Document> generarPDF({
    required String idMuestra,
    required String cultivo,
    required String titulo,
    required String uidUsuario,
  }) async {
    final pdf = pw.Document();

    // Obtener plantilla de secciones
    final docPlantilla = await FirebaseFirestore.instance
        .collection('PlantillasInforme')
        .doc('DATOS')
        .get();
    final secciones = List<String>.from(docPlantilla.data()?['CAMPO'] ?? []);

    // Obtener datos de muestra
    final docMuestra = await FirebaseFirestore.instance
        .collection('Muestras')
        .doc(idMuestra)
        .get();
    final datosMuestra = docMuestra.data() ?? {};

    // Obtener nombre de usuario (global)
    final nombreUsuario = usuario.nombreUsuario.isNotEmpty
        ? usuario.nombreUsuario
        : "No encontrado";

    // Cargar logo
    final logoBytes = await rootBundle.load('assets/COOPERATIVA.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Encabezado
    pdf.addPage(pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Image(logoImage, height: 100)),
          pw.SizedBox(height: 20),
          pw.Text(titulo, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('ID Muestra: $idMuestra'),
          pw.Text('Cultivo: $cultivo'),
          pw.Text('Usuario: $nombreUsuario'),
          pw.SizedBox(height: 20),
        ],
      ),
    ));

    // Obtener base URL actual
    final urlDoc = await FirebaseFirestore.instance
        .collection('ServidorFotos')
        .doc('configSalida')
        .get();
    final baseUrl = urlDoc.data()?['url'] ?? '';
    print('🌐 URL base del servidor: $baseUrl');

    for (final seccion in secciones) {
      final nombreColeccion = seccion;
      final nombreCampo = seccion.replaceFirst('Plantillas', '');

      final docSeccion = await FirebaseFirestore.instance
          .collection(nombreColeccion)
          .doc(cultivo)
          .get();

      final tituloSeccion = docSeccion.data()?['Titulo'] ?? nombreCampo;
      final campos = List<String>.from(docSeccion.data()?['CAMPO'] ?? []);

      print('📄 Procesando sección: $tituloSeccion');

      final filas = campos.map((campo) {
        final valor = datosMuestra[campo];
        String texto;
        if (valor is Timestamp) {
          final fecha = valor.toDate();
          texto = "${fecha.day.toString().padLeft(2, '0')}/"
                  "${fecha.month.toString().padLeft(2, '0')}/"
                  "${fecha.year} - "
                  "${fecha.hour.toString().padLeft(2, '0')}:"
                  "${fecha.minute.toString().padLeft(2, '0')}";
        } else {
          texto = valor?.toString() ?? '-';
        }
        return [campo, texto];
      }).toList();

      // Añadir tabla
      pdf.addPage(pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(tituloSeccion, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: filas
                  .map((fila) => pw.TableRow(
                        children: fila
                            .map((cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(cell),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ],
        ),
      ));

      // Buscar fotos
      print('🔍 Buscando fotos con idMuestra=$idMuestra, pantalla=$tituloSeccion');
      final fotos = await _obtenerFotosPorSeccion(idMuestra, tituloSeccion);
      print('🖼️ Rutas encontradas (${fotos.length}): $fotos');

      for (final ruta in fotos) {
        final urlCompleta = '$baseUrl/fotos/$ruta';
        print('🌐 Intentando cargar imagen desde: $urlCompleta');
        try {
          final response = await http.get(Uri.parse(urlCompleta));
          if (response.statusCode == 200) {
            final image = pw.MemoryImage(response.bodyBytes);
            pdf.addPage(pw.Page(
              build: (context) => pw.Center(
                child: pw.Image(image, height: 300),
              ),
            ));
          } else {
            print('❌ Error HTTP ${response.statusCode} al cargar imagen');
          }
        } catch (e) {
          print('❌ Excepción al cargar imagen: $e');
        }
      }
    }

    return pdf;
  }

  static Future<List<String>> _obtenerFotosPorSeccion(
      String idMuestra, String seccion) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Fotos')
          .where('idMuestra', isEqualTo: idMuestra)
          .where('pantalla', isEqualTo: seccion)
          .orderBy('timestamp')
          //.limit(2)
          .get();

      final rutas = snapshot.docs
          .map((doc) => doc['ruta_local'] as String?)
          .where((ruta) => ruta != null && ruta.toLowerCase().endsWith('.jpg'))
          .cast<String>()
          .toList();

      return rutas;
    } catch (e) {
      print('❌ Error al obtener fotos: $e');
      return [];
    }
  }
}
