import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/instrument_firestore.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/repository/job_repository.dart';
import 'package:neom_core/utils/enums/profile_type.dart';

class JobFirestore implements JobRepository {
  
  final profileInstrumentsReference = FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.profileInstruments);
  int documentTimelineCounter = 0;

  @override
  Future<void> createProfileInstrumentsCollection() async {
    AppConfig.logger.i("Setting ProfileInstrumentsCollection to improve finding musicians.");

    try {
      Map<String, AppProfile> profiles = await ProfileFirestore().retrieveAllProfiles();
      List<AppProfile> musicianProfiles = [];

      for (var profile in profiles.values) {
        if(profile.type == ProfileType.appArtist) {
          profile.instruments = await InstrumentFirestore().retrieveInstruments(profile.id);
          if(profile.instruments!.isNotEmpty) {
            //TODO IMPLEMENT WHEN USING THIS
            //profile.genres = await GenreFirestore().retrieveGenres(profile.id);
            musicianProfiles.add(profile);
          } else {
            AppConfig.logger.w("Instruments not found");
          }
        }
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var musicianProfile in musicianProfiles) {
        AppConfig.logger.i("Adding ${musicianProfile.name} with ${musicianProfile.instruments!.length} instruments");
        DocumentReference docRef = profileInstrumentsReference.doc(musicianProfile.id);
        batch.set(docRef, musicianProfile.toProfileInstrumentsJSON());
      }

      await batch.commit();
      AppConfig.logger.i("${musicianProfiles.length} musician profiles were added with their instruments.");

      AppUtilities.showSnackBar(
        title: "Rutinas de enlace de usuarios",
        message: "El enlace de usuarios ha sido actualizado satisfactoriamentes.",
      );

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_jobs', operation: 'createProfileInstrumentsCollection');
      AppUtilities.showSnackBar(
          title: "Rutinas de enlace de usuarios",
          message: "Hubo un error al actualizar el enlace de usuarios.");
    }
  }

}
