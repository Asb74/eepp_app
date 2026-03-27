import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> hayConexion() async {
  final resultado = await Connectivity().checkConnectivity();
  return resultado != ConnectivityResult.none;
}
