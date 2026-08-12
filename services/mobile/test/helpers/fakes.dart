import 'package:revenue_agent_app/core/services/location_service.dart';
import 'package:revenue_agent_app/core/services/photo_service.dart';
import 'package:revenue_agent_app/providers/sync_providers.dart';
import 'package:revenue_agent_app/repositories/sync_service.dart';

class FakePhotoService extends PhotoService {
  final String? path;

  FakePhotoService(this.path);

  @override
  Future<String?> captureFromCamera() async => path;
}

class FakeLocationService extends LocationService {
  final LocationFix fix;

  FakeLocationService(this.fix);

  @override
  Future<LocationFix> getCurrentFix() async => fix;
}

/// SyncController's real constructor kicks off a real sqflite (FFI) query
/// and a connectivity listener as soon as it is created - both are
/// Riverpod-managed background work that flutter_test's pump loop cannot
/// reliably observe completing (unlike a Future explicitly awaited by test
/// or event-handler code), which hangs pumpAndSettle even under
/// tester.runAsync(). Registration/payment widget tests only need to verify
/// the local save, not SyncController's own counting/connectivity behavior
/// (that is covered by its own use in the app and indirectly by
/// sync_service_test.dart), so both background calls are overridden to
/// no-ops here. Dart dispatches unqualified method calls in a constructor
/// body dynamically, so overriding these methods is enough to short-circuit
/// what the inherited constructor does - no constructor override needed.
class FakeSyncController extends SyncController {
  FakeSyncController(super.ref);

  @override
  Future<void> refreshPendingCounts() async {}

  @override
  Future<SyncOutcome> syncNow() async => SyncOutcome.empty;
}
