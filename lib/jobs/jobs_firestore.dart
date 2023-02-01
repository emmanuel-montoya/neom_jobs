import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_commons/core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_commons/core/data/firestore/genre_firestore.dart';
import 'package:neom_commons/core/data/firestore/instrument_firestore.dart';
import 'package:neom_commons/core/data/firestore/profile_firestore.dart';
import 'package:neom_commons/core/data/firestore/user_firestore.dart';
import 'package:neom_commons/core/domain/model/app_profile.dart';
import 'package:neom_commons/core/domain/model/app_user.dart';
import 'package:neom_commons/core/utils/app_utilities.dart';
import 'package:neom_commons/core/utils/enums/profile_type.dart';

import 'jobs_repository.dart';

class JobsFirestore implements JobsRepository {

  var logger = AppUtilities.logger;
  final profileInstrumentsReference = FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.profileInstruments);
  int documentTimelineCounter = 0;

  @override
  Future<void> createProfileInstrumentsCollection() async {
    logger.i("Setting ProfileInstrumentsCollection to improve finding musicians.");

    try {

      List<AppUser> users = await UserFirestore().getAll();
      List<AppProfile> musicianProfiles = [];

      for (var user in users) {
        musicianProfiles.addAll(await getProfilesInstruments(user.id));
      }

      for (var musicianProfile in musicianProfiles) {
        logger.i("Adding ${musicianProfile.name} with ${musicianProfile.instruments!.length} instruments");
          await profileInstrumentsReference
              .doc(musicianProfile.id)
              .set(musicianProfile.toProfileInstrumentsJSON());
      }
      logger.i("${musicianProfiles.length} musician profiles were added with their instruments.");
    } catch (e) {
    logger.e(e.toString());
    }
  }


  @override
  Future<List<AppProfile>> getProfilesInstruments(String userId) async {

    List<AppProfile> profiles = await ProfileFirestore().retrieveProfiles(userId);
    List<AppProfile> profilesWithInstruments = [];

    for (var profile in profiles) {

      profile.genres = await GenreFirestore().retrieveGenres(profile.id);

      if(profile.type == ProfileType.instrumentist) {
        profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
        if(profile.instruments!.isNotEmpty) {
          profilesWithInstruments.add(profile);
        } else {
          logger.w("Instruments not found");
        }
      }

    }

    return profilesWithInstruments;
  }

  @override
  Future<List<AppProfile>> distributeItemmates(String userId) async {

    List<AppProfile> profiles = await ProfileFirestore().retrieveProfiles(userId);
    List<AppProfile> profilesWithInstruments = [];

    for (var profile in profiles) {

      profile.genres = await GenreFirestore().retrieveGenres(profile.id);

      if(profile.type == ProfileType.instrumentist) {
        profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
        if(profile.instruments!.isNotEmpty) {
          profilesWithInstruments.add(profile);
        } else {
          logger.w("Instruments not found");
        }
      }

    }

    return profilesWithInstruments;
  }


}
