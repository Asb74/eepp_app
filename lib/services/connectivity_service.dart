import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'server_config_service.dart';

enum ConnectionStatus {
  online,
  offline,
  noServer,
}

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  final ValueNotifier<ConnectionStatus> statusNotifier =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.offline);

  StreamSubscription<dynamic>? _connectivitySubscription;
  ConnectionStatus _currentStatus = ConnectionStatus.offline;
  bool _started = false;
  String? _cachedServerUrl;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus get currentStatus => _currentStatus;

  bool get isOnline => _currentStatus == ConnectionStatus.online;

  bool get canReachServer => _currentStatus == ConnectionStatus.online;

  Future<void> startMonitoring() async {
    if (_started) return;
    _started = true;

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((dynamic result) async {
      await _evaluateAndEmit(connectivityResult: result);
    });

    await _evaluateAndEmit(notify: false);
  }

  Future<void> refresh() => _evaluateAndEmit();

  Future<void> _evaluateAndEmit({
    dynamic connectivityResult,
    bool notify = true,
  }) async {
    try {
      final dynamic networkResult =
          connectivityResult ?? await _connectivity.checkConnectivity();

      if (!_hasNetwork(networkResult)) {
        _emitStatus(ConnectionStatus.offline, notify: notify);
        return;
      }

      final bool reachable = await _canReachConfiguredServer();
      _emitStatus(
        reachable ? ConnectionStatus.online : ConnectionStatus.noServer,
        notify: notify,
      );
    } catch (_) {
      _emitStatus(ConnectionStatus.offline, notify: notify);
    }
  }

  bool _hasNetwork(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  Future<bool> _canReachConfiguredServer() async {
    final String serverUrl = await _resolveServerUrl();
    if (serverUrl.isEmpty) return false;

    final Uri? pingUri = _buildPingUri(serverUrl);
    if (pingUri == null) return false;

    try {
      final response = await http
          .get(
            pingUri,
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolveServerUrl() async {
    if (_cachedServerUrl != null && _cachedServerUrl!.isNotEmpty) {
      return _cachedServerUrl!;
    }

    final config = await getServerConfig();
    _cachedServerUrl = config.url.trim();
    return _cachedServerUrl!;
  }

  Uri? _buildPingUri(String serverUrl) {
    final Uri? baseUri = Uri.tryParse(serverUrl);
    if (baseUri == null) return null;

    final String pingPath = baseUri.path.endsWith('/')
        ? '${baseUri.path}test'
        : '${baseUri.path}/test';

    return baseUri.replace(path: pingPath);
  }

  void _emitStatus(ConnectionStatus status, {bool notify = true}) {
    if (_currentStatus == status) return;

    _currentStatus = status;
    statusNotifier.value = status;
    if (notify) {
      _statusController.add(status);
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _statusController.close();
    statusNotifier.dispose();
    _started = false;
  }
}
