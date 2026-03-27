import 'package:flutter/material.dart';
import 'grafica_donut_widget.dart';

class GraficaAutogenerada extends StatelessWidget {
  final String idMuestra;
  final String pantalla;
  final Map<String, dynamic> campos;

  const GraficaAutogenerada({
    super.key,
    required this.idMuestra,
    required this.pantalla,
    required this.campos,
  });

  @override
  Widget build(BuildContext context) {
    final datos = _extraerDatosGraficables(campos);
    if (datos.isEmpty) return const SizedBox(); // No grafica si no son válidos
    return GraficaDonutWidget(idMuestra: idMuestra, pantalla: pantalla, datos: datos);
  }

  Map<String, double> _extraerDatosGraficables(Map<String, dynamic> campos) {
    final mapa = <String, double>{};
    for (var entry in campos.entries) {
      final valor = double.tryParse(entry.value.toString().replaceAll('%', '').trim());
      if (valor != null && valor >= 0) {
        mapa[entry.key] = valor;
      }
    }

    final total = mapa.values.fold(0.0, (a, b) => a + b);
    if ((total - 100).abs() > 2.0) return {}; // Solo grafica si suma ≈ 100%

    return mapa;
  }
}
