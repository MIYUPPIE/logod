class GeoNode {
  final int id;
  final String name;
  final String? code;

  const GeoNode({required this.id, required this.name, this.code});

  factory GeoNode.fromJson(Map<String, dynamic> json) => GeoNode(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code};
}
