import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_muestra_page.dart';

// Clase para almacenar datos combinados Muestras + EEPP
class ResultadoBusqueda {
  final QueryDocumentSnapshot<Map<String, dynamic>> muestraDoc;
  final Map<String, dynamic> eeppData;

  ResultadoBusqueda(this.muestraDoc, this.eeppData);
}

class BuscarMuestraPage extends StatefulWidget {
  const BuscarMuestraPage({Key? key}) : super(key: key);

  @override
  State<BuscarMuestraPage> createState() => _BuscarMuestraPageState();
}

class _BuscarMuestraPageState extends State<BuscarMuestraPage> {
  final TextEditingController _controller = TextEditingController();

  bool _cargando = false;
  List<ResultadoBusqueda> _resultados = [];

  Future<void> _buscarMuestras(String texto) async {
    if (texto.isEmpty) {
      setState(() {
        _resultados = [];
      });
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      final eeppSnapshot = await FirebaseFirestore.instance
          .collection('EEPP')
          .orderBy('Nombre')
          .startAt([texto])
          .endAt(['$texto\uf8ff'])
          .get();

      if (eeppSnapshot.docs.isEmpty) {
        setState(() {
          _resultados = [];
          _cargando = false;
        });
        return;
      }

      final Map<String, Map<String, dynamic>> eeppMap = {
        for (var doc in eeppSnapshot.docs) doc.id: doc.data(),
      };

      final List<String> boletas = eeppSnapshot.docs.map((doc) => doc.id).toList();

      List<ResultadoBusqueda> resultadosCompletos = [];
      const batchSize = 10;

      for (var i = 0; i < boletas.length; i += batchSize) {
        final end = (i + batchSize > boletas.length) ? boletas.length : i + batchSize;
        final batch = boletas.sublist(i, end);

        final muestrasSnapshot = await FirebaseFirestore.instance
            .collection('Muestras')
            .where('Boleta', whereIn: batch)
            .orderBy('FechaHora', descending: true)
            .get();

        for (var muestraDoc in muestrasSnapshot.docs) {
          final boletaId = muestraDoc.data()['Boleta'];
          final eeppData = eeppMap[boletaId] ?? {};
          resultadosCompletos.add(ResultadoBusqueda(muestraDoc, eeppData));
        }
      }

      setState(() {
        _resultados = resultadosCompletos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _resultados = [];
        _cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar Muestra')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre de agricultor',
                border: OutlineInputBorder(),
              ),
              onChanged: (texto) {
                final textoMayus = texto.toUpperCase();
                if (texto != textoMayus) {
                  _controller.value = TextEditingValue(
                    text: textoMayus,
                    selection: TextSelection.collapsed(offset: textoMayus.length),
                  );
                }
                _buscarMuestras(textoMayus);
              },
            ),
            const SizedBox(height: 16),
            _cargando
                ? const CircularProgressIndicator()
                : Expanded(
                    child: _resultados.isEmpty
                        ? const Center(child: Text('No hay resultados'))
                        : ListView.builder(
                            itemCount: _resultados.length,
                            itemBuilder: (context, index) {
                              final resultado = _resultados[index];
                              final doc = resultado.muestraDoc;
                              final eeppData = resultado.eeppData;

                              final data = doc.data();
                              final fechaTimestamp = data['FechaHora'] as Timestamp?;
                              final fecha = fechaTimestamp != null
                                  ? fechaTimestamp.toDate().toLocal().toString()
                                  : 'N/A';
                              final boleta = data['Boleta'] ?? 'N/A';

                              final nombre = eeppData['Nombre'] ?? '';
                              final variedad = eeppData['Variedad'] ?? '';

                              return Card(
                                child: ListTile(
                                  title: Text('Boleta: $boleta'),
                                  subtitle: Text('Fecha: $fecha\nNombre: $nombre\nVariedad: $variedad'),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetalleMuestraPage(
                                          idMuestra: doc.id,
                                          fechaHora: fechaTimestamp!,
                                          boleta: boleta,
                                          nombre: nombre,
                                          variedad: variedad,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}
