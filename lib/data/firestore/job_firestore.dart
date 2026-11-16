import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/instrument_firestore.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/repository/job_repository.dart';
import 'package:neom_core/utils/enums/profile_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

class JobFirestore implements JobRepository {
  JobFirestore({
    FirebaseFirestore? firestore,
    ProfileFirestore? profileFirestore,
    InstrumentFirestore? instrumentFirestore,
  })  : _injectedFirestore = firestore,
        _injectedProfileFirestore = profileFirestore,
        _injectedInstrumentFirestore = instrumentFirestore;

  final FirebaseFirestore? _injectedFirestore;
  final ProfileFirestore? _injectedProfileFirestore;
  final InstrumentFirestore? _injectedInstrumentFirestore;

  FirebaseFirestore get _db => _injectedFirestore ?? FirebaseFirestore.instance;
  ProfileFirestore get _profileFirestore =>
      _injectedProfileFirestore ?? ProfileFirestore();
  InstrumentFirestore get _instrumentFirestore =>
      _injectedInstrumentFirestore ?? InstrumentFirestore();

  static const int maxBatchSize = 450;
  static const int maxConcurrentLookups = 20;

  static final RegExp _unsafeDocIdChars = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028-\u202E\u2060-\u2069\uFEFF/\\]',
  );
  static final RegExp _encodedIdTraversal = RegExp(
    r'%(?:2e|2f|5c|25|00|c2%[89][0-9a-f]|d8%9c|e2%80%(?:8[b-f]|a[8-e])|e2%81%a[0-9]|ef%bb%bf)',
    caseSensitive: false,
  );
  static final RegExp _reservedFirestoreId = RegExp(r'^__.*__$');

  @visibleForTesting
  static bool isSafeDocId(String raw) {
    if (_unsafeDocIdChars.hasMatch(raw) || _encodedIdTraversal.hasMatch(raw)) {
      return false;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > 128) return false;
    if (trimmed == '.' || trimmed == '..' || trimmed.contains('..')) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower == '__proto__' ||
        lower == 'constructor' ||
        lower == 'prototype' ||
        _reservedFirestoreId.hasMatch(trimmed)) {
      return false;
    }
    return true;
  }

  @visibleForTesting
  static List<List<T>> chunkForWriteBatch<T>(
    List<T> items, {
    int batchSize = maxBatchSize,
  }) {
    final safeSize = (!batchSize.isFinite || batchSize <= 0)
        ? maxBatchSize
        : (batchSize > 500 ? 500 : batchSize);
    if (items.isEmpty) return const [];
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += safeSize) {
      final end = (i + safeSize) < items.length ? (i + safeSize) : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  CollectionReference<Map<String, dynamic>> get profileInstrumentsReference =>
      _db.collection(AppFirestoreCollectionConstants.profileInstruments);
  int documentTimelineCounter = 0;

  @override
  Future<void> createProfileInstrumentsCollection() async {
    AppConfig.logger.i("Setting ProfileInstrumentsCollection to improve finding musicians.");

    try {
      final Map<String, AppProfile> profiles =
          await _profileFirestore.retrieveAllProfiles();
      final List<AppProfile> candidateArtists = profiles.values
          .where((p) => p.type == ProfileType.appArtist && isSafeDocId(p.id))
          .toList(growable: false);

      final List<AppProfile> musicianProfiles = [];
      for (final lookupChunk in chunkForWriteBatch(
        candidateArtists,
        batchSize: maxConcurrentLookups,
      )) {
        final resolved = await Future.wait(
          lookupChunk.map((profile) async {
            final cleanId = profile.id.trim();
            profile.instruments =
                await _instrumentFirestore.retrieveInstruments(cleanId);
            if (profile.instruments?.isNotEmpty ?? false) {
              return profile;
            }
            AppConfig.logger.w("Instruments not found");
            return null;
          }),
        );
        musicianProfiles.addAll(resolved.whereType<AppProfile>());
      }

      for (final chunk in chunkForWriteBatch(musicianProfiles)) {
        final batch = _db.batch();
        for (final musicianProfile in chunk) {
          final cleanId = musicianProfile.id.trim();
          AppConfig.logger.i(
            "Adding ${musicianProfile.name} with ${musicianProfile.instruments?.length ?? 0} instruments",
          );
          final docRef = profileInstrumentsReference.doc(cleanId);
          batch.set(docRef, musicianProfile.toProfileInstrumentsJSON());
        }
        await batch.commit();
      }
      AppConfig.logger.i(
        "${musicianProfiles.length} musician profiles were added with their instruments.",
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_jobs',
        operation: 'createProfileInstrumentsCollection',
      );
    }
  }

}
