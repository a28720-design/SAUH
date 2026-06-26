class Hospital {
  final String hospitalId;
  String name;
  String address;
  String contact;
  String hospitalCode;
  bool active;
  String createdBy;
  DateTime createdAt;

  Hospital({
    required this.hospitalId,
    required this.name,
    required this.address,
    required this.contact,
    required this.hospitalCode,
    this.active = true,
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'hospitalId': hospitalId,
      'nome': name,
      'morada': address,
      'contacto': contact,
      'codigoHospital': hospitalCode,
      'ativo': active,
      'criadoPor': createdBy,
      'dataCriacao': createdAt.toIso8601String(),
    };
  }
}
