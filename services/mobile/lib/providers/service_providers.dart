import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/location_service.dart';
import '../core/services/photo_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());
