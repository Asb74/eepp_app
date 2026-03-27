import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'datos_calibre.dart';
import 'datos_aprovechamientos.dart';
import 'condicion.dart';
import 'otros.dart';
import 'causas_destrio.dart';
import 'indice_madurez.dart';
import 'package:harvestsync/widgets/boton_informe_flotante.dart';

class DetalleMuestraPage extends StatefulWidget {
  final String idMuestra;
  final Timestamp fechaHora;
  final String boleta;
  final String nombre;
  final String variedad;

  const DetalleMuestraPage({
    super.key,
    required this.idMuestra,
    required this.fechaHora,
    required this.boleta,
    required this.nombre,
    required this.variedad,
  });

  @override
  State<DetalleMuestraPage> createState() => _DetalleMuestraPageState();
}

class _DetalleMuestraPageState extends State<DetalleMuestraPage> {
  final TextEditingController _albaranController = TextEditingController();
  String _tipoSeleccionado = 'Campo';
  bool _isScanning = false;
  String _cultivo = '';

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Muestras')
          .doc(widget.idMuestra)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final albaran = data['Albaran']?.toString() ?? '—';
        final tipo = data['Tipo']?.toString() ?? 'Campo';
        _cultivo = (data['CULTIVO'] ?? '').toString().toUpperCase();

        if (mounted) {
          setState(() {
            _albaranController.text = albaran;
            _tipoSeleccionado = ['Campo', 'Entrada', 'Otros'].contains(tipo) ? tipo : 'Campo';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos iniciales: $e')),
        );
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && mounted) {
        setState(() {
          _albaranController.text = code;
          _isScanning = false;
        });
        Navigator.of(context).pop();
        break;
      }
    }
  }

  void _abrirEscaner() {
    setState(() {
      _isScanning = true;
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: double.infinity,
            height: 400,
            child: Column(
              children: [
                AppBar(title: const Text('Escanear Albarán')),
                Expanded(
                  child: MobileScanner(
                    onDetect: _onDetect,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _guardarDatos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'desconocido';
    final docRef = FirebaseFirestore.instance.collection('Muestras').doc(widget.idMuestra);

    await docRef.update({
      'Albaran': _albaranController.text,
      'Tipo': _tipoSeleccionado,
      'Usuario': uid,
      'Nombre': widget.nombre,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos guardados correctamente')),
    );
  }

  @override
  void dispose() {
    _albaranController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fechaFormateada = widget.fechaHora.toDate().toLocal().toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Muestra')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Id Muestra: ${widget.idMuestra}'),
            Text('Fecha/Hora: $fechaFormateada'),
            Text('Boleta: ${widget.boleta}'),
            Text('Nombre: ${widget.nombre}'),
            Text('Variedad: ${widget.variedad}'),
            const SizedBox(height: 20),
            TextField(
              controller: _albaranController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Albarán (solo mediante escaneo)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _abrirEscaner,
                ),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Tipo'),
              value: _tipoSeleccionado,
              items: const [
                DropdownMenuItem(value: 'Campo', child: Text('Campo')),
                DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
                DropdownMenuItem(value: 'Otros', child: Text('Otros')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _tipoSeleccionado = value;
                  });
                }
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _guardarDatos,
              child: const Text('Guardar Datos'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DatosCalibrePage(
                      idMuestra: widget.idMuestra,
                      cultivo: _cultivo,
                    ),
                  ),
                );
              },
              child: const Text('Datos Calibres'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => DatosAprovechamientosPage(
                    idMuestra: widget.idMuestra,
                    cultivo: _cultivo,
                  ),
                ));
              },
              child: const Text('Datos Aprovechamientos'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CausasDestrioPage(
                      idMuestra: widget.idMuestra,
                      cultivo: _cultivo,
                    ),
                  ),
                );
              },
              child: const Text('Causas Industria'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => CondicionPage(
                    idMuestra: widget.idMuestra,
                    cultivo: _cultivo,
                  ),
                ));
              },
              child: const Text('Condición'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndiceMadurezPage(
                      idMuestra: widget.idMuestra,
                      cultivo: _cultivo,
                    ),
                  ),
                );
              },
              child: const Text('Índice Madurez'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtrosPage(
                      idMuestra: widget.idMuestra,
                      cultivo: _cultivo,
                    ),
                  ),
                );
              },
              child: const Text('Otros'),
            ),
          ],
        ),
      ),
      floatingActionButton: _cultivo.isEmpty
          ? null
          : BotonInformeFlotante(
              idMuestra: widget.idMuestra,
              cultivo: _cultivo,
            ),
    );
  }
}
