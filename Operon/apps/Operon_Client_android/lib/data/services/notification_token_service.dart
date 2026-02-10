import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationTokenService {
  NotificationTokenService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String _deviceIdKey = 'device_id';
  static const String _appId = 'client_android';
  static const String _platform = 'android';
  static const String _devicesCollection = 'DEVICES';

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<String>? _tokenSub;
  String? _deviceId;

  Future<void> start({
    required String organizationId,
    required String userId,
    String? phoneNumber,
  }) async {
    if (organizationId.isEmpty || userId.isEmpty) return;

    await _messaging.requestPermission();

    final resolvedUserId = await _resolveUserDocId(
      userId: userId,
      phoneNumber: phoneNumber,
    );
    if (resolvedUserId == null) {
      debugPrint(
          '[NotificationTokenService] No user document found for $userId');
      return;
    }

    _deviceId ??= await _getOrCreateDeviceId();
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _upsertDeviceDoc(
      deviceId: _deviceId!,
      token: token,
      userId: resolvedUserId,
      authUid: userId,
      organizationId: organizationId,
    );

    await _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((newToken) async {
      await _upsertDeviceDoc(
        deviceId: _deviceId!,
        token: newToken,
        userId: resolvedUserId,
        authUid: userId,
        organizationId: organizationId,
      );
    });
  }

  Future<void> clear() async {
    await _tokenSub?.cancel();
    _tokenSub = null;

    final deviceId = _deviceId;
    if (deviceId == null) return;

    try {
      await _firestore.collection(_devicesCollection).doc(deviceId).delete();
    } catch (_) {
      // Ignore missing device docs.
    }
  }

  Future<void> _upsertDeviceDoc({
    required String deviceId,
    required String token,
    required String userId,
    required String authUid,
    required String organizationId,
  }) async {
    final docRef = _firestore.collection(_devicesCollection).doc(deviceId);
    final doc = await docRef.get();

    await docRef.set({
      'deviceId': deviceId,
      'userId': userId,
      'authUid': authUid,
      'organizationId': organizationId,
      'appId': _appId,
      'platform': _platform,
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> _resolveUserDocId({
    required String userId,
    String? phoneNumber,
  }) async {
    final uidQuery = await _firestore
        .collection('USERS')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .get();
    if (uidQuery.docs.isNotEmpty) {
      return uidQuery.docs.first.id;
    }

    final authUser = _auth.currentUser;
    final phone = phoneNumber ?? authUser?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      for (final candidate in _phoneCandidates(phone)) {
        final phoneQuery = await _firestore
            .collection('USERS')
            .where('phone', isEqualTo: candidate)
            .limit(1)
            .get();
        if (phoneQuery.docs.isNotEmpty) {
          return phoneQuery.docs.first.id;
        }
      }
    }

    final directDoc = await _firestore.collection('USERS').doc(userId).get();
    if (directDoc.exists) {
      return directDoc.id;
    }

    return null;
  }

  Iterable<String> _phoneCandidates(String phone) {
    final trimmed = phone.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    final Set<String> candidates = {trimmed};
    if (digitsOnly.isNotEmpty) {
      candidates.add(digitsOnly);
      final numericOnly = digitsOnly.replaceAll(RegExp(r'[^0-9]'), '');
      candidates.add(numericOnly);
      if (!numericOnly.startsWith('+') && numericOnly.isNotEmpty) {
        candidates.add('+$numericOnly');
      }
    }
    return candidates.where((element) => element.isNotEmpty);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random();
    final deviceId =
        '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }
}
