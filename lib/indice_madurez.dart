import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvestsync/widgets/boton_foto_flotante.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';

class IndiceMadurezPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const IndiceMadurezPage({super.key, required this.idMuestra, required this.cultivo,});

  @override
  State<IndiceMadurezPage> createState() => _IndiceMadurezPageState();
}

class _IndiceMadurezPageState extends State<IndiceMadurezPage> {
  final Map<String, TextEditingController> _controladores = {};
  List<String> _nombresCampos = [];
  bool _cargandoDatos = true;
  bool _guardando = false;
  String _cultivo = '';

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
      _cultivo = (muestraData['CULTIVO'] ?? '').toString().toUpperCase();

      if (_cultivo.isEmpty) throw 'No se especificó el cultivo.';

      final plantillaDoc = await FirebaseFirestore.instance
          .collection('PlantillasGradosBrix')
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

      _controladores['Grados_Brix']?.addListener(_actualizarIndice);
      _controladores['Acidez']?.addListener(_actualizarIndice);

      _actualizarIndice();

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

  void _actualizarIndice() {
    final brix = _parseController(_controladores['Grados_Brix'] ?? TextEditingController());
    final acidez = _parseController(_controladores['Acidez'] ?? TextEditingController());

    if (brix > 0 && acidez > 0) {
      final indice = (brix / acidez).toStringAsFixed(2);
      _controladores['Indice_Madurez']?.text = indice;
    } else {
      _controladores['Indice_Madurez']?.text = '0.00';
    }

    if (mounted) {
      setState(() {});
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
    final brix = _parseController(_controladores['Grados_Brix'] ?? TextEditingController());
    final acidez = _parseController(_controladores['Acidez'] ?? TextEditingController());

    if (brix <= 0 || acidez <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grados Brix y Acidez deben ser mayores que 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final indice = double.parse((brix / acidez).toStringAsFixed(2));

    final Map<String, double> valores = {
      'Grados_Brix': brix,
      'Acidez': acidez,
      'Indice_Madurez': indice,
    };

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

  Widget _buildNumberField(String label, TextEditingController controller, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
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
        title: const Text('Índice de Madurez'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  ..._nombresCampos.map((campo) {
                    final esSoloLectura = campo == 'Indice_Madurez';
                    return _buildNumberField(
                      campo,
                      _controladores[campo]!,
                      readOnly: esSoloLectura,
                    );
                  }),
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
                  pantalla: 'Grados Brix',
                  cultivo: widget.cultivo,
                ),
              ],
            ),
    );
  }
}
