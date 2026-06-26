import '../models/app_role.dart';
import '../models/app_user.dart';

enum AppPermission {
  registerHospital,
  manageHospital,
  createUsers,
  manageUsers,
  viewPatients,
  createPatient,
  editPatientRecord,
  updateVitals,
  manageMedication,
  confirmAlerts,
  changePatientStatus,
  viewLimitedData,
  viewSystemData,
}

class PermissionService {
  static const Map<AppRole, Set<AppPermission>> _permissions = {
    AppRole.superAdmin: {
      AppPermission.registerHospital,
      AppPermission.manageHospital,
      AppPermission.createUsers,
      AppPermission.manageUsers,
      AppPermission.viewPatients,
      AppPermission.viewSystemData,
      AppPermission.viewLimitedData,
    },
    AppRole.adminHospital: {
      AppPermission.manageHospital,
      AppPermission.createUsers,
      AppPermission.manageUsers,
      AppPermission.viewPatients,
      AppPermission.createPatient,
      AppPermission.editPatientRecord,
      AppPermission.updateVitals,
      AppPermission.manageMedication,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewSystemData,
      AppPermission.viewLimitedData,
    },
    AppRole.diretorClinico: {
      AppPermission.viewPatients,
      AppPermission.createPatient,
      AppPermission.editPatientRecord,
      AppPermission.updateVitals,
      AppPermission.manageMedication,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewSystemData,
      AppPermission.viewLimitedData,
    },
    AppRole.chefeEnfermagem: {
      AppPermission.viewPatients,
      AppPermission.editPatientRecord,
      AppPermission.updateVitals,
      AppPermission.manageMedication,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewSystemData,
      AppPermission.viewLimitedData,
    },
    AppRole.medico: {
      AppPermission.viewPatients,
      AppPermission.editPatientRecord,
      AppPermission.manageMedication,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewLimitedData,
    },
    AppRole.enfermeiro: {
      AppPermission.viewPatients,
      AppPermission.updateVitals,
      AppPermission.manageMedication,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewLimitedData,
    },
    AppRole.triagem: {
      AppPermission.viewPatients,
      AppPermission.createPatient,
      AppPermission.changePatientStatus,
      AppPermission.viewLimitedData,
    },
    AppRole.tecnicoEmergencia: {
      AppPermission.viewPatients,
      AppPermission.createPatient,
      AppPermission.updateVitals,
      AppPermission.confirmAlerts,
      AppPermission.changePatientStatus,
      AppPermission.viewLimitedData,
    },
    AppRole.administrativo: {
      AppPermission.viewPatients,
      AppPermission.createPatient,
      AppPermission.changePatientStatus,
      AppPermission.viewLimitedData,
    },
    AppRole.auxiliar: {
      AppPermission.viewPatients,
      AppPermission.viewLimitedData,
    },
  };

  static bool can(AppUser? user, AppPermission permission) {
    if (user == null || !user.active) return false;
    return _permissions[user.role]?.contains(permission) ?? false;
  }

  static bool canAccessHospital(AppUser? user, String? hospitalId) {
    if (user == null || !user.active) return false;
    if (user.role == AppRole.superAdmin) return true;
    return user.hospitalId != null && user.hospitalId == hospitalId;
  }

  static bool canCreateRole(AppUser? creator, AppRole role) {
    if (creator == null || !creator.active) return false;
    if (creator.role == AppRole.superAdmin) {
      return role != AppRole.superAdmin;
    }
    if (creator.role == AppRole.adminHospital) {
      return role != AppRole.superAdmin && role != AppRole.adminHospital;
    }
    return false;
  }
}
