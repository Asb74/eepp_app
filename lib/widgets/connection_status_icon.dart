import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

class ConnectionStatusIcon extends StatelessWidget {
  const ConnectionStatusIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService.instance;

    return StreamBuilder<ConnectionStatus>(
      stream: service.statusStream,
      initialData: service.currentStatus,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Tooltip(
            message: 'Error de sincronización',
            child: Icon(Icons.error, color: Colors.red, size: size),
          );
        }

        final status = snapshot.data ?? ConnectionStatus.offline;
        final _StatusVisual visual = _statusVisualFor(status);

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: visual.tooltip,
            child: Icon(visual.icon, color: visual.color, size: size),
          ),
        );
      },
    );
  }

  _StatusVisual _statusVisualFor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.online:
        return const _StatusVisual(
          icon: Icons.cloud_done,
          color: Colors.green,
          tooltip: 'Conectado',
        );
      case ConnectionStatus.offline:
        return const _StatusVisual(
          icon: Icons.cloud_off,
          color: Colors.orange,
          tooltip: 'Sin conexión (modo local)',
        );
      case ConnectionStatus.noServer:
        return const _StatusVisual(
          icon: Icons.cloud_queue,
          color: Colors.amber,
          tooltip: 'Servidor no disponible',
        );
    }
  }
}

class ConnectionStatusSnackbarListener extends StatefulWidget {
  const ConnectionStatusSnackbarListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ConnectionStatusSnackbarListener> createState() =>
      _ConnectionStatusSnackbarListenerState();
}

class _ConnectionStatusSnackbarListenerState
    extends State<ConnectionStatusSnackbarListener> {
  StreamSubscription<ConnectionStatus>? _subscription;
  DateTime? _lastShown;

  @override
  void initState() {
    super.initState();
    _subscription = ConnectivityService.instance.statusStream.listen(_showMessage);
  }

  void _showMessage(ConnectionStatus status) {
    if (_lastShown != null &&
        DateTime.now().difference(_lastShown!).inMilliseconds < 1800) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    _lastShown = DateTime.now();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_messageForStatus(status)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _messageForStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.offline:
        return 'Sin conexión - trabajando en local';
      case ConnectionStatus.online:
        return 'Conexión restaurada';
      case ConnectionStatus.noServer:
        return 'Servidor no disponible';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StatusVisual {
  const _StatusVisual({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
}
