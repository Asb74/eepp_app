import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';
import 'detalle_muestra_page.dart';

class NuevaMuestraPage extends StatefulWidget {
  const NuevaMuestraPage({super.key});

  @override
  State<NuevaMuestraPage> createState() => _NuevaMuestraPageState();
}

class _NuevaMuestraPageState extends State<NuevaMuestraPage> {
  final TextEditingController _controller = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _resultados = [];
  bool _cargando = false;

  void _buscarSocios(String texto) async {
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
      final snapshot = await FirebaseFirestore.instance
          .collection('EEPP')
          .orderBy('Nombre')
          .startAt([texto.toUpperCase()])
          .endAt(['${texto.toUpperCase()}\uf8ff'])
          .limit(20)
          .get();

      setState(() {
        _resultados = snapshot.docs;
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

  void _crearMuestra(String boleta, String nombre, String variedad, String cultivo) async {
    final muestras = FirebaseFirestore.instance.collection('Muestras');

    final nuevoDoc = muestras.doc();
    final now = DateTime.now();

    final usuario = FirebaseAuth.instance.currentUser;
    final uid = usuario?.uid ?? 'desconocido';

    final data = {
      'IdMuestra': nuevoDoc.id,
      'FechaHora': Timestamp.fromDate(now),
      'Boleta': boleta,
      'Usuario': uid,
      'CULTIVO': cultivo,
    };
    final canUseServer = ConnectivityService.instance.canReachServer;

    if (canUseServer) {
      await nuevoDoc.set(data);
    } else {
      await OfflineWriteService.guardarLocalmente(
        collection: 'Muestras',
        documentId: nuevoDoc.id,
        data: data,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canUseServer
              ? '✅ Muestra creada con Boleta $boleta'
              : '💾 Muestra guardada localmente (sin conexión)',
        ),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleMuestraPage(
          idMuestra: nuevoDoc.id,
          fechaHora: Timestamp.fromDate(now),
          boleta: boleta,
          nombre: nombre,
          variedad: variedad,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Muestra')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Buscar socio por nombre...',
                border: OutlineInputBorder(),
              ),
              onChanged: _buscarSocios,
            ),
            const SizedBox(height: 16),
            _cargando
                ? const CircularProgressIndicator()
                : Expanded(
                    child: ListView.builder(
                      itemCount: _resultados.length,
                      itemBuilder: (context, index) {
                        final doc = _resultados[index];
                        final data = doc.data();
                        final boleta = doc.id;
                        final variedad = data['Variedad'] ?? '';
                        final parcela = data['Parcela'] ?? '';
                        final nombre = data['Nombre'] ?? '';

                        return Card(
                          child: ListTile(
                            title: Text('$nombre — $variedad'),
                            subtitle: Text('Parcela: $parcela'),
                            trailing: Text('Boleta: $boleta'),
                            onTap: () => _crearMuestra(boleta, nombre, variedad, data['CULTIVO'] ?? 'DESCONOCIDO'),
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
