import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'sync_queue_service.dart';

class OfflineWriteService {
  OfflineWriteService._();

  static Future<void> saveFirestoreOrQueue({
    required String collection,
    required String docId,
    required Map<String, dynamic> payload,
    bool merge = true,
  }) async {
    final status = ConnectivityService.instance.currentStatus;
    if (status == ConnectionStatus.online) {
      try {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .set(payload, SetOptions(merge: merge));
        return;
      } catch (e) {
        debugPrint('⚠️ set() falló, encolando: $e');
      }
    }

    await _queueFirestore(
      type: 'save_muestra_data',
      collection: collection,
      docId: docId,
      payload: payload,
      extra: <String, dynamic>{'merge': merge},
    );
  }

  static Future<void> updateFirestoreOrQueue({
    required String collection,
    required String docId,
    required Map<String, dynamic> payload,
  }) async {
    final status = ConnectivityService.instance.currentStatus;
    if (status == ConnectionStatus.online) {
      try {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .update(payload);
        return;
      } catch (e) {
        debugPrint('⚠️ update() falló, encolando: $e');
      }
    }

    await _queueFirestore(
      type: 'save_muestra_data',
      collection: collection,
      docId: docId,
      payload: payload,
      extra: const <String, dynamic>{'updateOnly': true},
    );
  }

  static Future<String> addFirestoreOrQueue({
    required String collection,
    required Map<String, dynamic> payload,
  }) async {
    final ref = FirebaseFirestore.instance.collection(collection).doc();
    final docId = ref.id;

    final dataWithId = <String, dynamic>{
      ...payload,
      if (!payload.containsKey('IdMuestra')) 'IdMuestra': docId,
    };

    await saveFirestoreOrQueue(
      collection: collection,
      docId: docId,
      payload: dataWithId,
      merge: false,
    );

    return docId;
  }

  static Future<void> guardarLocalmente({
    required String collection,
    String? documentId,
    required Map<String, dynamic> data,
  }) async {
    await _queueFirestore(
      type: 'save_muestra_data',
      collection: collection,
      docId: documentId,
      payload: data,
      extra: const <String, dynamic>{'updateOnly': false},
    );
  }

  static Future<void> _queueFirestore({
    required String type,
    required String collection,
    required String? docId,
    required Map<String, dynamic> payload,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    await SyncQueueService.instance.add(<String, dynamic>{
      'type': type,
      'collection': collection,
      'docId': docId,
      'payload': payload,
      ...extra,
    });

    debugPrint('📴 Guardado en cola local → $collection/${docId ?? '(auto-id)'}');
  }
}
