import 'package:flutter_test/flutter_test.dart';
import 'package:sauh/models/app_role.dart';
import 'package:sauh/models/app_user.dart';
import 'package:sauh/services/hospital_service.dart';
import 'package:sauh/services/permission_service.dart';

void main() {
  test('mapeia cargos recebidos do Supabase', () {
    expect(AppRole.fromSupabaseCargo('super_admin'), AppRole.superAdmin);
    expect(AppRole.fromSupabaseCargo('admin'), AppRole.adminHospital);
    expect(AppRole.fromSupabaseCargo('medico'), AppRole.medico);
    expect(AppRole.fromSupabaseCargo('enfermeiro'), AppRole.enfermeiro);
    expect(AppRole.fromSupabaseCargo('tecnico'), AppRole.tecnicoEmergencia);
    expect(AppRole.fromSupabaseCargo('rececionista'), AppRole.administrativo);
  });

  test('normaliza hospitais por id codigo ou nome', () {
    expect(
      hospitalService.normalizeHospitalId('hospital-central'),
      'hospital-central',
    );
    expect(hospitalService.normalizeHospitalId('HCL-001'), 'hospital-central');
    expect(
      hospitalService.normalizeHospitalId('Hospital Central de Lisboa'),
      'hospital-central',
    );
    expect(hospitalService.normalizeHospitalId('Hospital Principal'), isNull);
  });

  test('admin e super admin podem apagar, medico nao', () {
    final superAdmin = AppUser(
      userId: 'super',
      name: 'Super',
      email: 'super@sauh.pt',
      role: AppRole.superAdmin,
      hospitalId: null,
    );
    final admin = AppUser(
      userId: 'admin',
      name: 'Admin',
      email: 'admin@sauh.pt',
      role: AppRole.adminHospital,
      hospitalId: 'hospital-central',
    );
    final medico = AppUser(
      userId: 'medico',
      name: 'Medico',
      email: 'medico@sauh.pt',
      role: AppRole.medico,
      hospitalId: 'hospital-central',
    );

    expect(
      PermissionService.can(superAdmin, AppPermission.deletePatient),
      true,
    );
    expect(PermissionService.can(admin, AppPermission.deleteMedication), true);
    expect(PermissionService.can(medico, AppPermission.deletePatient), false);
    expect(
      PermissionService.can(medico, AppPermission.deleteMedication),
      false,
    );
  });
}
