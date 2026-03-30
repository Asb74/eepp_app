import 'dart:io';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';

class GraficaDonutWidget extends StatefulWidget {
  final String idMuestra;
  final String pantalla;
  final Map<String, double> datos;

  const GraficaDonutWidget({
    super.key,
    required this.idMuestra,
    required this.pantalla,
    required this.datos,
  });

  @override
  State<GraficaDonutWidget> createState() => _GraficaDonutWidgetState();
}

class _GraficaDonutWidgetState extends State<GraficaDonutWidget> {
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guardarGrafica());
  }

  Future<void> _guardarGrafica() async {
    try {
      final boundary = _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.idMuestra}_${widget.pantalla}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      final fotoData = {
        'idMuestra': widget.idMuestra,
        'pantalla': widget.pantalla,
        'timestamp': FieldValue.serverTimestamp(),
        'ruta': filePath,
      };
      final canUseServer = ConnectivityService.instance.canReachServer;
      if (canUseServer) {
        await FirebaseFirestore.instance.collection('Fotos').add(fotoData);
      } else {
        await OfflineWriteService.guardarLocalmente(
          collection: 'Fotos',
          data: fotoData,
        );
      }

      debugPrint('✅ Gráfica guardada: $filePath');
    } catch (e) {
      debugPrint('❌ Error al guardar la gráfica: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.datos.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key} (${entry.value.toInt()}%)',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12),
      );
    }).toList();

    return RepaintBoundary(
      key: _chartKey,
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 30,
            sectionsSpace: 2,
          ),
        ),
      ),
    );
  }
}
import 'dart:io';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GraficaDonutWidget extends StatefulWidget {
  final String idMuestra;
  final String pantalla;
  final Map<String, double> datos;

  const GraficaDonutWidget({
    super.key,
    required this.idMuestra,
    required this.pantalla,
    required this.datos,
  });

  @override
  State<GraficaDonutWidget> createState() => _GraficaDonutWidgetState();
}

class _GraficaDonutWidgetState extends State<GraficaDonutWidget> {
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guardarGrafica());
  }

  Future<void> _guardarGrafica() async {
    try {
      final boundary = _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.idMuestra}_${widget.pantalla}.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      final fotoData = {
        'idMuestra': widget.idMuestra,
        'pantalla': widget.pantalla,
        'timestamp': FieldValue.serverTimestamp(),
        'ruta': filePath,
      };
      final canUseServer = ConnectivityService.instance.canReachServer;
      if (canUseServer) {
        await FirebaseFirestore.instance.collection('Fotos').add(fotoData);
      } else {
        await OfflineWriteService.guardarLocalmente(
          collection: 'Fotos',
          data: fotoData,
        );
      }

      debugPrint('✅ Gráfica guardada: $filePath');
    } catch (e) {
      debugPrint('❌ Error al guardar la gráfica: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.datos.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key} (${entry.value.toInt()}%)',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12),
      );
    }).toList();

    return RepaintBoundary(
      key: _chartKey,
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 30,
            sectionsSpace: 2,
          ),
        ),
      ),
    );
  }
}
