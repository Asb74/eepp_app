import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvestsync/widgets/boton_foto_flotante.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';

class CausasDestrioPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const CausasDestrioPage({super.key, required this.idMuestra, required this.cultivo,});

  @override
  State<CausasDestrioPage> createState() => _CausasDestrioPageState();
}

class _CausasDestrioPageState extends State<CausasDestrioPage> {
  final Map<String, TextEditingController> _controladores = {};
  List<String> _nombresCampos = [];
  bool _cargandoDatos = true;
  bool _guardando = false;
  String _cultivo = ''; // ✅ Nuevo campo cultivo

  @override
  void initState() {
    super.initState();
    _cargarPlantillaYDatos();
  }

  Future<void> _cargarPlantillaYDatos() async {
    try {
      final muestraDoc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .get();

      if (!muestraDoc.exists) throw 'No se encontró la muestra.';

      final muestraData = muestraDoc.data()!;
      _cultivo = (muestraData['CULTIVO'] ?? '').toString().toUpperCase(); // ✅ guardar cultivo

      if (_cultivo.isEmpty) throw 'No se especificó el cultivo.';

      final plantillaDoc = await FirebaseFirestore.instance
          .collection('PlantillasDestrio')
          .doc(_cultivo)
          .get();

      if (!plantillaDoc.exists) throw 'No hay plantilla definida para $_cultivo.';

      final plantillaData = plantillaDoc.data();
      final campos = List<String>.from(plantillaData?['CAMPO'] ?? []);

      if (campos.isEmpty) throw 'La plantilla de $_cultivo no tiene campos.';

      for (var campo in campos) {
        final valorInicial = (muestraData[campo] ?? 0).toString();
        _controladores[campo] = TextEditingController(text: valorInicial);
      }

      setState(() {
        _nombresCampos = campos;
        _cargandoDatos = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _cargandoDatos = false;
      });
    }
  }

  double _parseController(TextEditingController c) {
    try {
      final val = double.parse(c.text.replaceAll(',', '.'));
      return val < 0 ? 0 : val;
    } catch (_) {
      return 0;
    }
  }

  void _guardarDatos() async {
    double suma = 0;
    final Map<String, double> valores = {};

    for (var campo in _nombresCampos) {
      final valor = _parseController(_controladores[campo]!);
      valores[campo] = valor;
      suma += valor;
    }

    if ((suma - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La suma debe ser 100%. Actualmente es ${suma.toStringAsFixed(2)}%.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .update(valores);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos guardados correctamente.'),
        ),
      );
    } catch (e) {
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

  @override
  void dispose() {
    for (var c in _controladores.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
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
        title: const Text('Causas Industria'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  ..._nombresCampos.map(
                    (campo) => _buildNumberField(campo, _controladores[campo]!),
                  ),
                  const SizedBox(height: 20),
                  _guardando
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _guardarDatos,
                            child: const Text('Guardar Datos'),
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
                  pantalla: 'Causas Industria',
                  cultivo: widget.cultivo,
                ),
              ],
            ),
    );
  }
}
