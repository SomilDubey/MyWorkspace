import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_guard/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  String _localKey(String uid) => 'local_user_$uid';

  Future<void> _saveLocal(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = user.toJson();

      // Firestore Timestamps are not JSON-encodable; store dates as ISO strings locally.
      map['createdAt'] = user.createdAt.toIso8601String();
      map['updatedAt'] = user.updatedAt.toIso8601String();

      await prefs.setString(_localKey(user.uid), jsonEncode(map));
    } catch (e) {
      debugPrint('UserService local save failed: $e');
    }
  }

  Future<UserModel?> _readLocal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey(uid));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return UserModel.fromJson(map);
    } catch (e) {
      debugPrint('UserService local read failed: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      // Note: docId = uid, so this cannot create duplicate users.
      await _firestore.collection(_collection).doc(user.uid).set(user.toJson());
      await _saveLocal(user);
    } catch (e) {
      debugPrint('Error creating user in Firestore (falling back to local): $e');
      await _saveLocal(user);
    }
  }

  Future<void> upsertUser(UserModel user) async {
    final docRef = _firestore.collection(_collection).doc(user.uid);
    final now = DateTime.now();

    try {
      final existingDoc = await docRef.get();
      UserModel toWrite;
      if (existingDoc.exists && existingDoc.data() != null) {
        final existing = UserModel.fromJson(existingDoc.data()!);
        toWrite = user.copyWith(createdAt: existing.createdAt, updatedAt: now);
      } else {
        toWrite = user.copyWith(createdAt: now, updatedAt: now);
      }

      // Merge to avoid accidentally wiping fields added later.
      await docRef.set(toWrite.toJson(), SetOptions(merge: true));
      await _saveLocal(toWrite);
    } catch (e) {
      debugPrint('Error upserting user in Firestore (falling back to local): $e');
      await _saveLocal(user.copyWith(updatedAt: now));
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromJson(doc.data()!);
        await _saveLocal(user);
        return user;
      }
      return await _readLocal(uid);
    } catch (e) {
      debugPrint('Error getting user from Firestore (falling back to local): $e');
      return await _readLocal(uid);
    }
  }

  Future<void> updateUser(UserModel user) async {
    final updated = user.copyWith(updatedAt: DateTime.now());
    try {
      await _firestore.collection(_collection).doc(updated.uid).update(updated.toJson());
      await _saveLocal(updated);
    } catch (e) {
      debugPrint('Error updating user in Firestore (falling back to local): $e');
      await _saveLocal(updated);
    }
  }

  Stream<UserModel?> userStream(String uid) {
    return _firestore.collection(_collection).doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromJson(doc.data()!);
        _saveLocal(user);
        return user;
      }
      return null;
    });
  }
}
