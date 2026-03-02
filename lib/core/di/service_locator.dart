import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../../core/services/location_service.dart';
import '../../data/datasources/local/contacts_local_datasource.dart';
import '../../data/repositories/contacts_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../network/api_client.dart';
import '../security/encryption_service.dart';
import '../security/secure_storage.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (serviceLocator.isRegistered<Dio>()) {
    return;
  }
  final dio = ApiClient.build();
  serviceLocator.registerSingleton<Dio>(dio);

  // Offline-first services - no Firebase dependencies
  serviceLocator.registerSingleton<LocationService>(LocationService());
  serviceLocator.registerLazySingleton<ContactsLocalDataSource>(
    () => ContactsLocalDataSource(),
  );
  serviceLocator.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(serviceLocator<LocationService>()),
  );
  serviceLocator.registerLazySingleton<ContactsRepository>(
    () => ContactsRepositoryImpl(serviceLocator<ContactsLocalDataSource>()),
  );
  serviceLocator.registerLazySingleton<SecureStorage>(() => SecureStorage());
  serviceLocator.registerLazySingleton<EncryptionService>(
    () => EncryptionService(),
  );
}

