import 'package:flutter/material.dart';
import 'package:harvestsync/screens/informe_viewer_page.dart';

class BotonInformeFlotante extends StatelessWidget {
  final String? idMuestra;
  final String cultivo;

  const BotonInformeFlotante({
    super.key,
    required this.idMuestra,
    required this.cultivo,
  });

  @override
  Widget build(BuildContext context) {
    if (idMuestra == null || idMuestra!.isEmpty) return const SizedBox.shrink();

    return FloatingActionButton(
      heroTag: 'informe',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InformeViewerPage(
              idMuestra: idMuestra!, // forzamos porque ya validamos arriba
              cultivo: cultivo,
            ),
          ),
        );
      },
      tooltip: 'Generar informe',
      child: const Icon(Icons.picture_as_pdf),
    );
  }
}
