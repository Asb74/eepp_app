import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'nueva_muestra.dart';
import 'buscar_muestra.dart';
import 'login.dart';
import 'usuario_actual.dart' as usuario;
import 'services/server_config_service.dart';
import 'services/connectivity_service.dart';
import 'widgets/connection_status_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ConnectivityService.instance.startMonitoring();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HarvestSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      builder: (context, child) {
        return ConnectionStatusSnackbarListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreenWrapper();
        }
        return const LoginPage();
      },
    );
  }
}

class HomeScreenWrapper extends StatefulWidget {
  const HomeScreenWrapper({super.key});

  @override
  State<HomeScreenWrapper> createState() => _HomeScreenWrapperState();
}

class _HomeScreenWrapperState extends State<HomeScreenWrapper> {
  bool _cargando = true;
  bool _autorizado = true;

  @override
  void initState() {
    super.initState();
    _verificarYcargarUsuario();
  }

  Future<void> _verificarYcargarUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('UsuariosAutorizados')
            .doc(user.uid)
            .get();

        final data = doc.data();
        if (data != null && data['Valor'] == true) {
          usuario.uidUsuario = user.uid;
          usuario.nombreUsuario = data['Nombre'] ?? '';
          usuario.correoUsuario = data['correo'] ?? '';

          try {
            final serverConfig = await getServerConfig();
            usuario.rutaServidor = serverConfig.rutaServidor;
            print(
              "📥 Ruta destino cargada desde Firebase: ${usuario.rutaServidor}",
            );
          } catch (e) {
            print("❌ Error config: $e");
          }
        } else {
          _autorizado = false;
          await FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      print("❌ Error en _verificarYcargarUsuario: $e");
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_autorizado) {
      return const Scaffold(
        body: Center(
          child: Text(
            '❌ Usuario no autorizado',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HarvestSync'),
        centerTitle: true,
        actions: const [
          ConnectionStatusIcon(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO CON TAMAÑO DINÁMICO Y SOMBRA
              Builder(builder: (context) {
                final double logoSize = MediaQuery.of(context).size.width * 0.25;
                return Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/icono_app.png', fit: BoxFit.cover),
                  ),
                );
              }),
              const SizedBox(height: 30),

              // BOTONES
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nueva Muestra'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NuevaMuestraPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar Muestra'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BuscarMuestraPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text(
                'HarvestSync - Versión de prueba',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
