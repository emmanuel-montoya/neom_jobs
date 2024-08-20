import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_commons/core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_commons/core/data/firestore/genre_firestore.dart';
import 'package:neom_commons/core/data/firestore/instrument_firestore.dart';
import 'package:neom_commons/core/data/firestore/profile_firestore.dart';
import 'package:neom_commons/core/domain/model/app_profile.dart';
import 'package:neom_commons/core/utils/app_utilities.dart';
import 'package:neom_commons/core/utils/enums/profile_type.dart';

import 'jobs_repository.dart';

class JobsFirestore implements JobsRepository {
  
  final profileInstrumentsReference = FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.profileInstruments);
  int documentTimelineCounter = 0;

  @override
  Future<void> createProfileInstrumentsCollection() async {
    AppUtilities.logger.i("Setting ProfileInstrumentsCollection to improve finding musicians.");

    try {
      Map<String, AppProfile> profiles = await ProfileFirestore().retrieveAllProfiles();
      List<AppProfile> musicianProfiles = [];

      for (var profile in profiles.values) {
        if(profile.type == ProfileType.artist) {
          profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
          if(profile.instruments!.isNotEmpty) {
            //TODO IMPLEMENT WHEN USING THIS
            //profile.genres = await GenreFirestore().retrieveGenres(profile.id);
            musicianProfiles.add(profile);
          } else {
            AppUtilities.logger.w("Instruments not found");
          }
        }
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var musicianProfile in musicianProfiles) {
        AppUtilities.logger.i("Adding ${musicianProfile.name} with ${musicianProfile.instruments!.length} instruments");
        DocumentReference docRef = profileInstrumentsReference.doc(musicianProfile.id);
        batch.set(docRef, musicianProfile.toProfileInstrumentsJSON());
      }

      await batch.commit();
      AppUtilities.logger.i("${musicianProfiles.length} musician profiles were added with their instruments.");

      AppUtilities.showSnackBar(
        title: "Rutinas de enlace de usuarios",
        message: "El enlace de usuarios ha sido actualizado satisfactoriamentes.",
      );

    } catch (e) {
      AppUtilities.logger.e(e.toString());
      AppUtilities.showSnackBar(
          title: "Rutinas de enlace de usuarios",
          message: "Hubo un error al actualizar el enlace de usuarios.");
    }
  }


  ///DEPRECATED
  // @override
  // Future<List<AppProfile>> getProfilesInstruments(String userId) async {
  //
  //   List<AppProfile> profiles = await ProfileFirestore().retrieveProfiles(userId);
  //   List<AppProfile> profilesWithInstruments = [];
  //
  //   for (var profile in profiles) {
  //
  //     profile.genres = await GenreFirestore().retrieveGenres(profile.id);
  //
  //     if(profile.type == ProfileType.instrumentist) {
  //       profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
  //       if(profile.instruments!.isNotEmpty) {
  //         profilesWithInstruments.add(profile);
  //       } else {
  //         AppUtilities.logger.w("Instruments not found");
  //       }
  //     }
  //
  //   }
  //
  //   return profilesWithInstruments;
  // }


  @override
  Future<List<AppProfile>> distributeItemmates(String userId) async {

    List<AppProfile> profiles = await ProfileFirestore().retrieveProfiles(userId);
    List<AppProfile> profilesWithInstruments = [];

    for (var profile in profiles) {

      profile.genres = await GenreFirestore().retrieveGenres(profile.id);

      if(profile.type == ProfileType.artist) {
        profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
        if(profile.instruments!.isNotEmpty) {
          profilesWithInstruments.add(profile);
        } else {
          AppUtilities.logger.w("Instruments not found");
        }
      }

    }

    return profilesWithInstruments;
  }


}
