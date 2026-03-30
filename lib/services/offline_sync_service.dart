import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'foto_sync_service.dart';
import 'sync_queue_service.dart';

class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  StreamSubscription<ConnectionStatus>? _statusSubscription;
  bool _initialized = false;
  bool _isSyncing = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await SyncQueueService.instance.init();

    _statusSubscription = ConnectivityService.instance.statusStream.listen((status) {
      if (status == ConnectionStatus.online) {
        refresh();
      }
    });

    if (ConnectivityService.instance.currentStatus == ConnectionStatus.online) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (_isSyncing) {
      debugPrint('ℹ️ Sync ya en ejecución, se omite refresh superpuesto.');
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 Iniciando procesamiento de cola offline...');

    try {
      while (ConnectivityService.instance.currentStatus == ConnectionStatus.online) {
        final items = await SyncQueueService.instance.getPendingItems();
        if (items.isEmpty) {
          debugPrint('✅ Cola vacía.');
          break;
        }

        final item = Map<String, dynamic>.from(items.first);
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }

        try {
          final ok = await _executeItem(item);
          if (ok) {
            await SyncQueueService.instance.removeById(id);
            debugPrint('✅ Item sincronizado: $id (${item['type']})');
          } else {
            await SyncQueueService.instance.markFailed(id, 'No se pudo ejecutar item');
            debugPrint('⚠️ Item pendiente conservado: $id (${item['type']})');
            break;
          }
        } catch (e) {
          await SyncQueueService.instance.markFailed(id, e);
          debugPrint('❌ Error sincronizando item $id: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _executeItem(Map<String, dynamic> item) async {
    final type = item['type']?.toString();

    switch (type) {
      case 'save_muestra_data':
        return _syncFirestoreItem(item);
      case 'upload_foto':
        return FotoSyncService.instance.syncQueuedPhoto(item);
      case 'upload_pdf':
        return false;
      default:
        debugPrint('⚠️ Tipo no soportado en cola: $type');
        return false;
    }
  }

  Future<bool> _syncFirestoreItem(Map<String, dynamic> item) async {
    final collection = item['collection']?.toString();
    if (collection == null || collection.isEmpty) return false;

    final decodedPayload = SyncQueueService.instance.decodeValue(item['payload']);
    if (decodedPayload is! Map<String, dynamic>) return false;

    final docId = item['docId']?.toString();
    final updateOnly = item['updateOnly'] == true;
    final merge = item['merge'] != false;

    final collectionRef = FirebaseFirestore.instance.collection(collection);

    if (docId == null || docId.isEmpty) {
      await collectionRef.add(decodedPayload);
      return true;
    }

    final docRef = collectionRef.doc(docId);

    if (updateOnly) {
      await docRef.set(decodedPayload, SetOptions(merge: true));
    } else {
      await docRef.set(decodedPayload, SetOptions(merge: merge));
    }

    return true;
  }

  Future<void> dispose() async {
    await _statusSubscription?.cancel();
  }
}
