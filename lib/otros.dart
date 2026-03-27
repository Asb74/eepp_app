import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvestsync/widgets/boton_foto_flotante.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';

class CampoConfigurado {
  final String nombre;
  final List<String> opciones; // vacío = TextField

  CampoConfigurado({required this.nombre, this.opciones = const []});
}

class OtrosPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const OtrosPage({
    Key? key,
    required this.idMuestra,
    required this.cultivo,
  }) : super(key: key);

  @override
  State<OtrosPage> createState() => _OtrosPageState();
}

class _OtrosPageState extends State<OtrosPage> {
  bool _cargando = true;
  bool _guardando = false;
  String _cultivo = '';

  List<CampoConfigurado> campos = [];
  Map<String, String?> valores = {};

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _cargarDatosIniciales();
    await _cargarCamposDesdePlantilla();
    setState(() {
      _cargando = false;
    });
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _cultivo = (data['CULTIVO'] ?? '').toString().toUpperCase();

        for (final key in data.keys) {
          if (data[key] is String) {
            valores[key] = data[key];
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _cargarCamposDesdePlantilla() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('PlantillasOtros')
          .doc(_cultivo)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final List campoArray = data?['CAMPO'] ?? [];

        final List<CampoConfigurado> nuevosCampos = [];

        for (final raw in campoArray) {
          final match = RegExp(r'^(.*?)\s*\[(.*?)\]$').firstMatch(raw);
          if (match != null) {
            final nombre = match.group(1)!.trim();
            final opciones = match.group(2)!
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            nuevosCampos.add(CampoConfigurado(nombre: nombre, opciones: opciones));
          } else {
            final nombre = raw.toString().trim();
            nuevosCampos.add(CampoConfigurado(nombre: nombre)); // sin opciones = TextField
          }
        }

        setState(() {
          campos = nuevosCampos;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la plantilla del cultivo.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar plantilla: $e')),
      );
    }
  }

  Future<void> _guardarDatos() async {
    setState(() {
      _guardando = true;
    });
    try {
      final Map<String, dynamic> datosAGuardar = {};
      for (var campo in campos) {
        datosAGuardar[campo.nombre] = valores[campo.nombre];
      }

      await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .update(datosAGuardar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar datos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Widget _buildCampo(CampoConfigurado campo) {
    if (campo.opciones.isNotEmpty) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: campo.nombre),
        value: valores[campo.nombre],
        items: campo.opciones
            .map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ))
            .toList(),
        onChanged: _guardando
            ? null
            : (val) => setState(() {
                  valores[campo.nombre] = val;
                }),
        isExpanded: true,
      );
    } else {
      return TextFormField(
        decoration: InputDecoration(labelText: campo.nombre),
        initialValue: valores[campo.nombre] ?? '',
        enabled: !_guardando,
        onChanged: (val) => valores[campo.nombre] = val,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Otros Datos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  for (var campo in campos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildCampo(campo),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardarDatos,
                    child: _guardando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Guardar Datos'),
                  ),
                ],
              ),
      ),
      floatingActionButton: _cargando
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
                  pantalla: 'Otros',
                  cultivo: widget.cultivo,
                ),
              ],
            ),
    );
  }
}
