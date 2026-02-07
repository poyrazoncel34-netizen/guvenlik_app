import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/location_service.dart';
import '../../data/datasources/local/contacts_local_datasource.dart';
import '../../data/datasources/remote/firebase_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/contacts_repository_impl.dart';
import '../../data/repositories/emergency_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/emergency_repository.dart';
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
  serviceLocator.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  serviceLocator.registerSingleton<FirebaseService>(FirebaseService.instance);
  serviceLocator.registerSingleton<LocationService>(LocationService());
  serviceLocator.registerLazySingleton<ContactsLocalDataSource>(() => ContactsLocalDataSource());
  serviceLocator.registerLazySingleton<FirebaseRemoteDataSource>(
    () => FirebaseRemoteDataSource(serviceLocator<FirebaseService>()),
  );

  serviceLocator.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(serviceLocator<FirebaseAuth>()),
  );
  serviceLocator.registerLazySingleton<EmergencyRepository>(
    () => EmergencyRepositoryImpl(serviceLocator<FirebaseRemoteDataSource>()),
  );
  serviceLocator.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(serviceLocator<LocationService>()),
  );
  serviceLocator.registerLazySingleton<ContactsRepository>(
    () => ContactsRepositoryImpl(serviceLocator<ContactsLocalDataSource>()),
  );
  serviceLocator.registerLazySingleton<SecureStorage>(() => SecureStorage());
  serviceLocator.registerLazySingleton<EncryptionService>(() => EncryptionService());
}
