import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:harvestsync/services/foto_sync_service.dart';
import 'muestra_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference muestrasRef = FirebaseFirestore.instance.collection('Muestras');
  late final StreamSubscription _conexionSubscription;

  @override
  void initState() {
    super.initState();

    // Paso 7: subir al iniciar
    subirFotosPendientes();

    // Paso 8: subir al recuperar conexión
    _conexionSubscription = Connectivity().onConnectivityChanged.listen((estado) {
      if (estado != ConnectivityResult.none) {
        subirFotosPendientes();
      }
    });
  }

  @override
  void dispose() {
    _conexionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Muestras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => MuestraForm()));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: muestrasRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text('Sin muestras registradas.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text('Boleta: ${data['boleta'] ?? 'Sin datos'}'),
                subtitle: Text('Variedad: ${data['variedad'] ?? 'Desconocida'}'),
              );
            },
          );
        },
      ),
    );
  }
}
