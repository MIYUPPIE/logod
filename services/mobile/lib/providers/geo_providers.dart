import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo_node.dart';
import '../models/levy_type.dart';
import 'repository_providers.dart';

final statesProvider = FutureProvider<List<GeoNode>>(
  (ref) => ref.watch(geoRepositoryProvider).states(),
);

final lgasProvider = FutureProvider.family<List<GeoNode>, int>(
  (ref, stateId) => ref.watch(geoRepositoryProvider).lgas(stateId),
);

final wardsProvider = FutureProvider.family<List<GeoNode>, int>(
  (ref, lgaId) => ref.watch(geoRepositoryProvider).wards(lgaId),
);

final marketsProvider = FutureProvider.family<List<GeoNode>, int>(
  (ref, wardId) => ref.watch(geoRepositoryProvider).markets(wardId),
);

final levyTypesProvider = FutureProvider.family<List<LevyType>, int>(
  (ref, lgaId) => ref.watch(levyTypeRepositoryProvider).forLga(lgaId),
);
