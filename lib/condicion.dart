import 'package:flutter/material.dart';
import 'package:harvestsync/widgets/app_bar_actions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvestsync/widgets/boton_foto_flotante.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';
import 'package:harvestsync/services/connectivity_service.dart';
import 'package:harvestsync/services/offline_write_service.dart';

class CondicionPage extends StatefulWidget {
  final String idMuestra;
  final String cultivo;

  const CondicionPage({Key? key, required this.idMuestra, required this.cultivo,}) : super(key: key);

  @override
  State<CondicionPage> createState() => _CondicionPageState();
}

class _CondicionPageState extends State<CondicionPage> {
  String? _estadoMadurez;
  String? _semillas;
  String? _sabor;
  String? _color;
  String? _olor;
  String? _pulpa;
  String? _textura;

  String _cultivo = ''; // ✅ Para BotonInformeFlotante
  bool _cargandoDatos = true;
  bool _guardando = false;

  final List<String> estadosMadurez = ['Optimo', 'Inmaduro', 'Maduro'];
  final List<String> nivelesSemillas = ['Nada', 'Puntual', 'Preocupante', 'Generalizado'];
  final List<String> valoraciones = ['Muy Bien', 'Bien', 'Regular', 'Malo'];
  final List<String> valoracionesPulpa = ['Muy Bien', 'Bien', 'Regular', 'Mala'];

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
        if (mounted) {
          setState(() {
            _estadoMadurez = data['EstadoMadurez'];
            _semillas = data['Semillas'];
            _sabor = data['Sabor'];
            _color = data['Color'];
            _olor = data['Olor'];
            _pulpa = data['Pulpa'];
            _textura = data['Textura'];
            _cultivo = (data['CULTIVO'] ?? '').toString().toUpperCase();
            _cargandoDatos = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cargandoDatos = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoDatos = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _guardarDatos() async {
    setState(() {
      _guardando = true;
    });
    try {
      final data = {
        'EstadoMadurez': _estadoMadurez,
        'Semillas': _semillas,
        'Sabor': _sabor,
        'Color': _color,
        'Olor': _olor,
        'Pulpa': _pulpa,
        'Textura': _textura,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              canUseServer
                  ? 'Datos guardados correctamente.'
                  : '💾 Datos guardados localmente (sin conexión)',
            ),
          ),
        );
      }
    } catch (e) {
      if (!ConnectivityService.instance.canReachServer) {
        return;
      }
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

  DropdownButtonFormField<String> _buildDropdown({
    required String label,
    required List<String> items,
    String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ))
          .toList(),
      onChanged: _guardando ? null : onChanged,
      isExpanded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condición'),
        actions: kConnectionStatusActions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _cargandoDatos
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _buildDropdown(
                    label: 'Estado Madurez',
                    items: estadosMadurez,
                    value: _estadoMadurez,
                    onChanged: (val) => setState(() => _estadoMadurez = val),
                  ),
                  _buildDropdown(
                    label: 'Semillas',
                    items: nivelesSemillas,
                    value: _semillas,
                    onChanged: (val) => setState(() => _semillas = val),
                  ),
                  _buildDropdown(
                    label: 'Sabor',
                    items: valoraciones,
                    value: _sabor,
                    onChanged: (val) => setState(() => _sabor = val),
                  ),
                  _buildDropdown(
                    label: 'Color',
                    items: valoraciones,
                    value: _color,
                    onChanged: (val) => setState(() => _color = val),
                  ),
                  _buildDropdown(
                    label: 'Olor',
                    items: valoraciones,
                    value: _olor,
                    onChanged: (val) => setState(() => _olor = val),
                  ),
                  _buildDropdown(
                    label: 'Pulpa',
                    items: valoracionesPulpa,
                    value: _pulpa,
                    onChanged: (val) => setState(() => _pulpa = val),
                  ),
                  _buildDropdown(
                    label: 'Textura',
                    items: valoracionesPulpa,
                    value: _textura,
                    onChanged: (val) => setState(() => _textura = val),
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
                  pantalla: 'Condición',
                  cultivo: widget.cultivo,
                ),
              ],
            ),
    );
  }
}
