enum SyncStatus { pendingSync, synced, flagged, duplicateSuspected;

  static SyncStatus fromDb(String value) => SyncStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => SyncStatus.pendingSync,
      );

  String toDb() => name;

  String get label => switch (this) {
        SyncStatus.pendingSync => 'Pending sync',
        SyncStatus.synced => 'Synced',
        SyncStatus.flagged => 'Flagged',
        SyncStatus.duplicateSuspected => 'Duplicate suspected',
      };
}

enum RecordOrigin { local, remoteCache;

  static RecordOrigin fromDb(String value) =>
      value == 'remote_cache' ? RecordOrigin.remoteCache : RecordOrigin.local;

  String toDb() => switch (this) {
        RecordOrigin.local => 'local',
        RecordOrigin.remoteCache => 'remote_cache',
      };
}
