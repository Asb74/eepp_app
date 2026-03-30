import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvestsync/widgets/boton_foto_flotante.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';
import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';

class DatosAprovechamientosPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const DatosAprovechamientosPage({Key? key, required this.idMuestra, required this.cultivo,}) : super(key: key);

  @override
  State<DatosAprovechamientosPage> createState() => _DatosAprovechamientosPageState();
}

class _DatosAprovechamientosPageState extends State<DatosAprovechamientosPage> {
  final TextEditingController destrioController = TextEditingController(text: '0');
  final TextEditingController industriaController = TextEditingController(text: '0');
  final TextEditingController categoriaIController = TextEditingController(text: '0');
  final TextEditingController categoriaIIController = TextEditingController(text: '0');

  bool _guardando = false;
  bool _cargandoDatos = true;
  String _cultivo = ''; // ✅ Añadido cultivo

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Muestras').doc(widget.idMuestra).get();

      if (doc.exists) {
        final data = doc.data()!;
        destrioController.text = (data['Destrio'] ?? 0).toString();
        industriaController.text = (data['Industria'] ?? 0).toString();
        categoriaIController.text = (data['Categoria I'] ?? 0).toString();
        categoriaIIController.text = (data['Categoria II'] ?? 0).toString();
        _cultivo = (data['CULTIVO'] ?? '').toString().toUpperCase(); // ✅ Leer cultivo
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargandoDatos = false;
        });
      }
    }
  }

  void _guardarDatos() async {
    final destrio = double.tryParse(destrioController.text) ?? 0.0;
    final industria = double.tryParse(industriaController.text) ?? 0.0;
    final categoriaI = double.tryParse(categoriaIController.text) ?? 0.0;
    final categoriaII = double.tryParse(categoriaIIController.text) ?? 0.0;

    final suma = destrio + industria + categoriaI + categoriaII;

    if ((suma - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El total debe ser 100%'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final data = {
        'Destrio': destrio,
        'Industria': industria,
        'Categoria I': categoriaI,
        'Categoria II': categoriaII,
      };
      final canUseServer = ConnectivityService.instance.canReachServer;

      if (canUseServer) {
        await FirebaseFirestore.instance
            .collection('Muestras')
            .doc(widget.idMuestra)
            .update(data);
      } else {
        await OfflineWriteService.guardarLocalmente(
          collection: 'Muestras',
          documentId: widget.idMuestra,
          data: data,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canUseServer
                ? 'Datos guardados correctamente'
                : '💾 Datos guardados localmente (sin conexión)',
          ),
        ),
      );
    } catch (e) {
      if (!ConnectivityService.instance.canReachServer) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Widget _buildNumericField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos Aprovechamientos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildNumericField('Destrío', destrioController),
                  _buildNumericField('Industria', industriaController),
                  _buildNumericField('Categoria I', categoriaIController),
                  _buildNumericField('Categoria II', categoriaIIController),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarDatos,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar Datos'),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _cargandoDatos
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BotonInformeFlotante(
                  idMuestra: widget.idMuestra,
                  cultivo: _cultivo,
                ),
                const SizedBox(height: 10),
                BotonFotoFlotante(
                  idMuestra: widget.idMuestra,
                  pantalla: 'Aprovechamiento',
                  cultivo: widget.cultivo,
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    destrioController.dispose();
    industriaController.dispose();
    categoriaIController.dispose();
    categoriaIIController.dispose();
    super.dispose();
  }
}
