enum UserRole { admin, supervisor, agent, seller;

  static UserRole fromJson(String value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.agent,
      );
}

class AppUser {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final int? lgaId;
  final String? deviceId;
  final bool active;

  const AppUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.lgaId,
    this.deviceId,
    required this.active,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: UserRole.fromJson(json['role'] as String),
        lgaId: json['lga_id'] as int?,
        deviceId: json['device_id'] as String?,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'lga_id': lgaId,
        'device_id': deviceId,
        'active': active,
      };
}
