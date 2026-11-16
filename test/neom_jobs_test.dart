import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/data/firestore/instrument_firestore.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/instrument.dart';
import 'package:neom_core/utils/enums/profile_type.dart';
import 'package:neom_jobs/data/firestore/job_firestore.dart';

class _FakeProfileFirestore implements ProfileFirestore {
  final Map<String, AppProfile> seed;
  _FakeProfileFirestore(this.seed);

  @override
  Future<Map<String, AppProfile>> retrieveAllProfiles({
    bool forceRefresh = false,
    int limit = 200,
  }) async => seed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConcurrentInstrumentFirestore implements InstrumentFirestore {
  int inFlight = 0;
  int maxObservedConcurrency = 0;

  @override
  Future<Map<String, Instrument>> retrieveInstruments(String profileId) async {
    inFlight++;
    if (inFlight > maxObservedConcurrency) {
      maxObservedConcurrency = inFlight;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
    inFlight--;
    return {
      'guitar': Instrument(id: 'guitar', name: 'Guitar'),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWriteBatch implements WriteBatch {
  final List<String> writtenDocIds = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writtenDocIds.add(document.id);
  }

  @override
  Future<void> commit() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  @override
  final String id;
  _FakeDocRef(this.id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocRef(path ?? 'auto');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseFirestore implements FirebaseFirestore {
  final _FakeWriteBatch lastBatch = _FakeWriteBatch();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionRef();

  @override
  WriteBatch batch() => lastBatch;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('isSafeDocId rejects traversal and control chars', () {
    expect(JobFirestore.isSafeDocId('artist_123'), isTrue);
    expect(JobFirestore.isSafeDocId('../secret'), isFalse);
    expect(JobFirestore.isSafeDocId('__reserved__'), isFalse);
    expect(JobFirestore.isSafeDocId('a/b'), isFalse);
  });

  test('createProfileInstrumentsCollection parallelizes instrument lookups without UI snackbars', () async {
    final profiles = <String, AppProfile>{
      for (var i = 0; i < 5; i++)
        'artist_$i': AppProfile(
          id: 'artist_$i',
          name: 'Artist $i',
          type: ProfileType.appArtist,
        ),
      'fan_1': AppProfile(
        id: 'fan_1',
        name: 'Fan 1',
        type: ProfileType.general,
      ),
    };
    final fakeDb = _FakeFirebaseFirestore();
    final fakeProfiles = _FakeProfileFirestore(profiles);
    final fakeInstruments = _ConcurrentInstrumentFirestore();

    final jobFirestore = JobFirestore(
      firestore: fakeDb,
      profileFirestore: fakeProfiles,
      instrumentFirestore: fakeInstruments,
    );

    await jobFirestore.createProfileInstrumentsCollection();

    expect(fakeInstruments.maxObservedConcurrency, greaterThan(1));
    expect(
      fakeDb.lastBatch.writtenDocIds,
      equals(['artist_0', 'artist_1', 'artist_2', 'artist_3', 'artist_4']),
    );
  });
}
