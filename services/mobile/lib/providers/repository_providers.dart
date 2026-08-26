import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_repository.dart';
import '../repositories/geo_repository.dart';
import '../repositories/levy_type_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/seller_repository.dart';
import '../repositories/sync_service.dart';
import 'auth_providers.dart';
import 'db_providers.dart';

final geoRepositoryProvider = Provider<GeoRepository>((ref) => GeoRepository(
      dio: ref.watch(dioProvider),
      db: ref.watch(appDatabaseProvider).db,
    ));

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(dio: ref.watch(dioProvider)));

final levyTypeRepositoryProvider = Provider<LevyTypeRepository>((ref) => LevyTypeRepository(
      dio: ref.watch(dioProvider),
      db: ref.watch(appDatabaseProvider).db,
    ));

final sellerRepositoryProvider = Provider<SellerRepository>((ref) => SellerRepository(
      dio: ref.watch(dioProvider),
      db: ref.watch(appDatabaseProvider).db,
    ));

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(db: ref.watch(appDatabaseProvider).db),
);

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(
      dio: ref.watch(dioProvider),
      sellerRepository: ref.watch(sellerRepositoryProvider),
      paymentRepository: ref.watch(paymentRepositoryProvider),
    ));
