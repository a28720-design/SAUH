import '../models/hospital.dart';

class HospitalService {
  final List<Hospital> _hospitals = [
    Hospital(
      hospitalId: 'hospital-central',
      name: 'Hospital Central de Lisboa',
      address: 'Lisboa',
      contact: '210 000 000',
      hospitalCode: 'HCL-001',
      createdBy: 'seed',
    ),
    Hospital(
      hospitalId: 'hospital-norte',
      name: 'Hospital Norte',
      address: 'Porto',
      contact: '220 000 000',
      hospitalCode: 'HN-001',
      createdBy: 'seed',
    ),
  ];

  List<Hospital> get hospitals => List.unmodifiable(_hospitals);

  Hospital? byId(String? hospitalId) {
    if (hospitalId == null) return null;
    for (final hospital in _hospitals) {
      if (hospital.hospitalId == hospitalId) return hospital;
    }
    return null;
  }

  Hospital registerHospital({
    required String name,
    required String address,
    required String contact,
    required String hospitalCode,
    required bool active,
    required String createdBy,
  }) {
    final hospital = Hospital(
      hospitalId: 'hospital-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      address: address,
      contact: contact,
      hospitalCode: hospitalCode,
      active: active,
      createdBy: createdBy,
    );
    _hospitals.add(hospital);
    return hospital;
  }

  void setHospitalActive(String hospitalId, bool active) {
    final hospital = byId(hospitalId);
    if (hospital != null) hospital.active = active;
  }
}

final hospitalService = HospitalService();
