import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SyncQueueService {
  SyncQueueService._();

  static final SyncQueueService instance = SyncQueueService._();

  static const String _queueFileName = 'pending_sync_queue.json';

  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromDisk();
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    await init();
    return List<Map<String, dynamic>>.from(_queue);
  }

  Future<void> add(Map<String, dynamic> rawItem) async {
    await init();
    final now = DateTime.now().toUtc().toIso8601String();

    final Map<String, dynamic> item = <String, dynamic>{
      'id': rawItem['id']?.toString().trim().isNotEmpty == true
          ? rawItem['id'].toString().trim()
          : _nextId(),
      'status': 'pending',
      'createdAt': rawItem['createdAt']?.toString() ?? now,
      ...rawItem,
    };

    _queue.add(_deepEncode(item));
    await _saveToDisk();
  }

  Future<void> removeById(String id) async {
    await init();
    _queue.removeWhere((item) => item['id'] == id);
    await _saveToDisk();
  }

  Future<void> markFailed(String id, Object error) async {
    await init();
    for (final item in _queue) {
      if (item['id'] == id) {
        item['lastError'] = error.toString();
        item['lastAttemptAt'] = DateTime.now().toUtc().toIso8601String();
        break;
      }
    }
    await _saveToDisk();
  }

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_queueFileName');
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _queueFile();
      if (!await file.exists()) {
        await file.writeAsString('[]');
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _queue
          ..clear()
          ..addAll(decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) {
      debugPrint('❌ Error cargando cola local: $e');
      _queue.clear();
    }
  }

  Future<void> _saveToDisk() async {
    final file = await _queueFile();
    await file.writeAsString(
      jsonEncode(_queue),
      flush: true,
    );
  }

  String _nextId() {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().millisecondsSinceEpoch}_$random';
  }

  Map<String, dynamic> _deepEncode(Map<String, dynamic> value) {
    return value.map((key, val) => MapEntry(key, _encodeValue(val)));
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return <String, dynamic>{
        '__type': 'timestamp',
        'millis': value.millisecondsSinceEpoch,
      };
    }
    if (value is DateTime) {
      return <String, dynamic>{
        '__type': 'datetime',
        'iso': value.toUtc().toIso8601String(),
      };
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  dynamic decodeValue(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (map['__type'] == 'timestamp' && map['millis'] is int) {
        return Timestamp.fromMillisecondsSinceEpoch(map['millis'] as int);
      }
      if (map['__type'] == 'datetime' && map['iso'] is String) {
        return DateTime.tryParse(map['iso'] as String);
      }
      return map.map((k, v) => MapEntry(k, decodeValue(v)));
    }
    if (value is List) {
      return value.map(decodeValue).toList();
    }
    return value;
  }
}
