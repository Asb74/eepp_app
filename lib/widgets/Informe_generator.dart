import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:harvestsync/usuario_actual.dart' as usuario;
import 'package:harvestsync/services/server_config_service.dart';

class InformeGenerator {
  static Future<pw.Document> generarPDF({
  required String idMuestra,
  required String cultivo,
  required String titulo,
  required String uidUsuario,
}) async {
  final pdf = pw.Document();
  final contenido = <pw.Widget>[];

  final docPlantilla = await FirebaseFirestore.instance
      .collection('PlantillasInforme')
      .doc('DATOS')
      .get();
  final secciones = List<String>.from(docPlantilla.data()?['CAMPO'] ?? []);

  final docMuestra = await FirebaseFirestore.instance
      .collection('Muestras')
      .doc(idMuestra)
      .get();
  final datosMuestra = docMuestra.data() ?? {};

  final nombreUsuario = usuario.nombreUsuario.isNotEmpty
      ? usuario.nombreUsuario
      : "No encontrado";

  final logoBytes = await rootBundle.load('assets/COOPERATIVA.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  contenido.addAll([
    pw.Center(child: pw.Image(logoImage, height: 100)),
    pw.SizedBox(height: 20),
    pw.Text(titulo, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 10),
    pw.Text('ID Muestra: $idMuestra'),
    pw.Text('Cultivo: $cultivo'),
    pw.Text('Usuario: $nombreUsuario'),
    pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
    pw.SizedBox(height: 20),
  ]);

  final serverConfig = await getServerConfig();
  final baseUrl = serverConfig.url;

  for (final seccion in secciones) {
    final nombreColeccion = seccion;
    final nombreCampo = seccion.replaceFirst('Plantillas', '');

    final docSeccion = await FirebaseFirestore.instance
        .collection(nombreColeccion)
        .doc(cultivo)
        .get();

    final tituloSeccion = docSeccion.data()?['Titulo'] ?? nombreCampo;
    final camposRaw = List<String>.from(docSeccion.data()?['CAMPO'] ?? []);
    final campos = camposRaw.map((e) => e.split('[').first.trim()).toList();


    final filas = campos.map((campo) {
      final valor = datosMuestra[campo];
      String texto;
      if (valor is Timestamp) {
        final fecha = valor.toDate();
        texto = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
      } else {
        texto = valor?.toString() ?? '-';
      }
      return [campo, texto];
    }).toList();

    contenido.addAll([
      pw.SizedBox(height: 20),
      pw.Text(tituloSeccion, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey),
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
    ]);

    if (_esGraficaPosible(filas)) {
      contenido.add(pw.SizedBox(height: 20));
      contenido.add(_crearGrafica(filas));
    }

    // Obtener imágenes desde el servidor según rutaServidor
    final fotos = await _obtenerFotosPorSeccion(idMuestra, tituloSeccion);
    final imagenes = <pw.Widget>[];
    final carpeta = Uri.encodeComponent(usuario.rutaServidor);

    for (final ruta in fotos) {
      final urlCompleta = '$baseUrl/fotos/$ruta?carpeta=$carpeta';
      try {
        final response = await http.get(
          Uri.parse(urlCompleta),
          headers: {'X-API-KEY': serverConfig.apiKey},
        );
        print("🌐 Petición a: $urlCompleta → ${response.statusCode}");
        if (response.statusCode == 200) {
          final image = pw.MemoryImage(response.bodyBytes);
          imagenes.add(pw.Image(image, height: 120, width: 120));
        } else {
          print("❌ Error al obtener imagen: ${response.statusCode}");
        }
      } catch (e) {
        print("🚫 Excepción al obtener imagen: $e");
      }
    }

    if (imagenes.isNotEmpty) {
      contenido.add(pw.SizedBox(height: 10));
      contenido.add(pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: imagenes,
      ));
    }
  }

  pdf.addPage(pw.MultiPage(
    build: (context) => contenido,
  ));

  return pdf;
}


  static bool _esGraficaPosible(List<List<String>> filas) {
    try {
      final valores = filas.map((e) => double.parse(e[1])).toList();
      final suma = valores.reduce((a, b) => a + b);
      return (suma > 99.5 && suma < 100.5);
    } catch (_) {
      return false;
    }
  }

  static pw.Widget _crearGrafica(List<List<String>> filas) {
    final valores = filas.map((e) => double.tryParse(e[1]) ?? 0).toList();
    final etiquetas = filas.map((e) => e[0]).toList();
    final maxValor = valores.reduce((a, b) => a > b ? a : b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Gráfico de distribución', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        ...List.generate(filas.length, (i) {
          final ancho = (valores[i] / maxValor) * 300;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 80, child: pw.Text(etiquetas[i])),
                pw.Container(width: ancho, height: 12, color: PdfColors.blueGrey400),
                pw.SizedBox(width: 10),
                pw.Text('${valores[i].toStringAsFixed(1)}%'),
              ],
            ),
          );
        })
      ],
    );
  }

  static Future<List<String>> _obtenerFotosPorSeccion(String idMuestra, String seccion) async {
    print("📥 [INICIO] _obtenerFotosPorSeccion");
    print("🧩 idMuestra: $idMuestra");
    print("🧩 sección: $seccion");

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Fotos')
          .where('idMuestra', isEqualTo: idMuestra)
          .where('pantalla', isEqualTo: seccion)
          .orderBy('timestamp')
          .get();

      print("📦 Documentos encontrados: ${snapshot.docs.length}");

      final rutas = snapshot.docs.map((doc) {
        final ruta = doc['ruta_local'];
        print("🖼 Foto encontrada → ruta_local: $ruta");
        return ruta;
      }).where((ruta) {
        final isValid = ruta != null && ruta.toLowerCase().endsWith('.jpg');
        if (!isValid) print("⚠️ Ruta descartada (no es .jpg): $ruta");
        return isValid;
      }).cast<String>().toList();

      print("✅ Total rutas .jpg válidas: ${rutas.length}");
      return rutas;
    } catch (e) {
      print("❌ Error en _obtenerFotosPorSeccion: $e");
      return [];
    }
  }

}
