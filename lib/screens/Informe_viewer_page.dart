import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:harvestsync/widgets/informe_generator.dart';
import 'package:harvestsync/usuario_actual.dart' as usuario;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

class InformeViewerPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const InformeViewerPage({
    super.key,
    required this.idMuestra,
    required this.cultivo,
  });

  @override
  State<InformeViewerPage> createState() => _InformeViewerPageState();
}

class _InformeViewerPageState extends State<InformeViewerPage> {
  bool _cargando = true;
  String? _pdfPath;

  @override
  void initState() {
    super.initState();
    _generarInforme();
  }

  Future<void> _generarInforme() async {
    setState(() => _cargando = true);

    final pdf = await InformeGenerator.generarPDF(
      idMuestra: widget.idMuestra,
      cultivo: widget.cultivo,
      titulo: 'Informe de Muestra',
      uidUsuario: usuario.uidUsuario,
    );

    final bytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${widget.idMuestra}_informe.pdf');
    await tempFile.writeAsBytes(bytes);

    setState(() {
      _pdfPath = tempFile.path;
      _cargando = false;
    });
  }

  Future<void> _subirPDFAlServidor() async {
    try {
      final file = File(_pdfPath!);
      final bytes = await file.readAsBytes();

      final urlDoc = await FirebaseFirestore.instance
          .collection('ServidorFotos')
          .doc('url_actual')
          .get();
      final urlServidor = urlDoc.data()?['url'];
      if (urlServidor == null || urlServidor.isEmpty) {
        throw 'URL del servidor no disponible.';
      }

      final uri = Uri.parse('$urlServidor/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['idMuestra'] = widget.idMuestra
        ..fields['pantalla'] = 'InformePDF'
        ..fields['boleta'] = ''
        ..fields['rutaDestino'] = usuario.rutaServidor
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ PDF subido correctamente al servidor.')),
          );
        }
      } else {
        throw 'Código de error: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al subir PDF: $e')),
        );
      }
    }
  }

  Future<void> _imprimirPDF() async {
    if (_pdfPath == null) return;
    final file = File(_pdfPath!);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> _compartirPDF() async {
    if (_pdfPath == null) return;
    await Share.shareXFiles([XFile(_pdfPath!)], text: 'Informe de muestra');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informe de Muestra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Subir al servidor',
            onPressed: _pdfPath != null ? _subirPDFAlServidor : null,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir',
            onPressed: _pdfPath != null ? _imprimirPDF : null,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: _pdfPath != null ? _compartirPDF : null,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pdfPath == null
              ? const Center(child: Text('No se pudo renderizar el PDF.'))
              : PdfViewer.file(_pdfPath!),
    );
  }
}
