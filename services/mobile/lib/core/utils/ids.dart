import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newClientUuid() => _uuid.v4();

String nowIso() => DateTime.now().toUtc().toIso8601String();
