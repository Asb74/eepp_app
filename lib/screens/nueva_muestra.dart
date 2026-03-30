import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';

class NuevaMuestra extends StatefulWidget {
  const NuevaMuestra({super.key});

  @override
  State<NuevaMuestra> createState() => _NuevaMuestraState();
}

class _NuevaMuestraState extends State<NuevaMuestra> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _boletaController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  String? _cultivoSeleccionado;

  final List<String> _cultivos = ['Naranja', 'Mandarina', 'Caqui', 'Sandía'];

  Future<void> _guardarMuestra() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'boleta': _boletaController.text.trim(),
        'cultivo': _cultivoSeleccionado,
        'observaciones': _observacionesController.text.trim(),
        'fecha': Timestamp.now(),
      };

      final canUseServer = ConnectivityService.instance.canReachServer;
      if (canUseServer) {
        await FirebaseFirestore.instance.collection('Muestras').add(data);
      } else {
        await OfflineWriteService.guardarLocalmente(
          collection: 'Muestras',
          data: data,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canUseServer
                ? '✅ Muestra guardada'
                : '💾 Muestra guardada localmente (sin conexión)',
          ),
        ),
      );

      _formKey.currentState!.reset();
      setState(() {
        _cultivoSeleccionado = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Muestra')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _boletaController,
                decoration: const InputDecoration(labelText: 'Boleta'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _cultivoSeleccionado,
                decoration: const InputDecoration(labelText: 'Cultivo'),
                items: _cultivos
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => _cultivoSeleccionado = value),
                validator: (value) =>
                    value == null ? 'Selecciona un cultivo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _guardarMuestra,
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
