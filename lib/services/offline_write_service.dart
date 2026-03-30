import 'package:flutter/foundation.dart';

class OfflineWriteService {
  OfflineWriteService._();

  static final List<Map<String, dynamic>> _pendingWrites =
      <Map<String, dynamic>>[];

  static Future<void> guardarLocalmente({
    required String collection,
    String? documentId,
    required Map<String, dynamic> data,
  }) async {
    _pendingWrites.add(<String, dynamic>{
      'collection': collection,
      'documentId': documentId,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    });

    debugPrint('📴 Guardando en local (sin conexión) → $collection/${documentId ?? '(auto-id)'}');
  }

  static List<Map<String, dynamic>> get pendingWrites =>
      List<Map<String, dynamic>>.unmodifiable(_pendingWrites);
}
