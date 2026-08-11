import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => ref.watch(connectivityProvider).onConnectivityChanged,
);

bool isOnlineResult(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
