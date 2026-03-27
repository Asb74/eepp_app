import 'dart:io';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GraficaMuestraWidget extends StatefulWidget {
  final String idMuestra;

  const GraficaMuestraWidget({super.key, required this.idMuestra});

  @override
  State<GraficaMuestraWidget> createState() => _GraficaMuestraWidgetState();
}

class _GraficaMuestraWidgetState extends State<GraficaMuestraWidget> {
  final GlobalKey _chartKey = GlobalKey();

  Future<void> _guardarGrafica() async {
    try {
      final boundary = _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.idMuestra}_grafica.png';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Subir a Firestore como metadata (la ruta local)
      await FirebaseFirestore.instance.collection('Fotos').add({
        'idMuestra': widget.idMuestra,
        'pantalla': 'Graficas',
        'timestamp': FieldValue.serverTimestamp(),
        'ruta': filePath,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gráfica guardada correctamente.')),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar la gráfica: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          key: _chartKey,
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 20, width: 20)]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 35, width: 20)]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 50, width: 20)]),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
                    return Text(['Cal 1-3', 'Cal 4-7', 'Cal 8'][value.toInt()]);
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _guardarGrafica,
          icon: const Icon(Icons.save),
          label: const Text('Guardar gráfica'),
        ),
      ],
    );
  }
}
