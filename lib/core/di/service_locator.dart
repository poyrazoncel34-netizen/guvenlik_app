import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import '../../core/services/location_service.dart';
import '../../core/services/local_database_service.dart';
import '../../core/services/revenue_cat_service.dart';
import '../../data/datasources/local/contacts_local_datasource.dart';
import '../../data/repositories/contacts_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../security/encryption_service.dart';
import '../security/secure_storage.dart';
import '../../services/consent_manager.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Offline-first services - no Firebase, no network dependencies
  if (!kIsWeb && !serviceLocator.isRegistered<LocalDatabaseService>()) {
    final databaseService = LocalDatabaseService();
    await databaseService.initialize();
    serviceLocator.registerSingleton<LocalDatabaseService>(databaseService);
  }
  if (!serviceLocator.isRegistered<LocationService>()) {
    serviceLocator.registerSingleton<LocationService>(LocationService());
  }
  if (!serviceLocator.isRegistered<ContactsLocalDataSource>()) {
    serviceLocator.registerLazySingleton<ContactsLocalDataSource>(
      () => ContactsLocalDataSource(),
    );
  }
  if (!serviceLocator.isRegistered<LocationRepository>()) {
    serviceLocator.registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(serviceLocator<LocationService>()),
    );
  }
  if (!serviceLocator.isRegistered<ContactsRepository>()) {
    serviceLocator.registerLazySingleton<ContactsRepository>(
      () => ContactsRepositoryImpl(serviceLocator<ContactsLocalDataSource>()),
    );
  }
  if (!serviceLocator.isRegistered<SecureStorage>()) {
    serviceLocator.registerLazySingleton<SecureStorage>(() => SecureStorage());
  }
  if (!serviceLocator.isRegistered<EncryptionService>()) {
    serviceLocator.registerLazySingleton<EncryptionService>(
      () => EncryptionService(),
    );
  }
  if (!serviceLocator.isRegistered<ConsentManager>()) {
    final consentManager = ConsentManager();
    await consentManager.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consentManager);
  }
  if (!serviceLocator.isRegistered<RevenueCatService>()) {
    serviceLocator.registerLazySingleton<RevenueCatService>(
      () => RevenueCatService(),
    );
  }
}
