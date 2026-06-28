import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_role.dart';
import '../models/app_user.dart';

class SupabaseAccountException implements Exception {
  final String message;

  const SupabaseAccountException(this.message);

  @override
  String toString() => message;
}

class SupabaseAccountService {
  const SupabaseAccountService();

  Future<AppUser?> currentProfile(SupabaseClient client) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return null;

    final rows = await client
        .from('app_users')
        .select()
        .eq('auth_user_id', authUser.id)
        .limit(1);

    return _firstUserFromRows(rows);
  }

  Future<List<AppUser>> loadVisibleAccounts(
    SupabaseClient client,
    AppUser actor,
  ) async {
    dynamic query = client.from('app_users').select();
    if (actor.role != AppRole.superAdmin) {
      final hospitalId = actor.hospitalId;
      if (hospitalId == null || hospitalId.isEmpty) return const [];
      query = query.eq('hospital', hospitalId);
    }

    final rows = await query.order('nome');
    return _usersFromRows(rows);
  }

  Future<AppUser> createAccount({
    required SupabaseClient client,
    required AppUser creator,
    required String name,
    required String email,
    required String temporaryPassword,
    required String cargo,
    required AppRole role,
    required String department,
    required bool active,
    required String? hospitalId,
  }) async {
    final normalizedCargo = cargo.trim();
    if (normalizedCargo.isEmpty) {
      throw const SupabaseAccountException(
        'Seleciona um cargo antes de criar a conta.',
      );
    }

    final response = await _invokeAccountFunction(client, {
      'action': 'create',
      'nome': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': temporaryPassword,
      'cargo': normalizedCargo,
      'departamento': _normalizedDepartment(department),
      'ativo': active,
      'hospital': hospitalId,
      'hospital_id': hospitalId,
      'created_by': creator.userId,
    });
    return _userFromFunctionResponse(response);
  }

  Future<AppUser> updateAccount({
    required SupabaseClient client,
    required AppUser actor,
    required AppUser target,
    required String name,
    required String email,
    required AppRole role,
    required String department,
    required bool active,
    required String? hospitalId,
    String? newPassword,
  }) async {
    final password = newPassword?.trim() ?? '';
    final response = await _invokeAccountFunction(client, {
      'action': 'update',
      'auth_user_id': target.userId,
      'nome': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password.isEmpty ? null : password,
      'cargo': _cargoForRole(role),
      'departamento': _normalizedDepartment(department),
      'ativo': active,
      'hospital': hospitalId,
      'hospital_id': hospitalId,
      'updated_by': actor.userId,
    });
    return _userFromFunctionResponse(response);
  }

  Future<dynamic> _invokeAccountFunction(
    SupabaseClient client,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await client.functions.invoke(
        'manage-account',
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        throw SupabaseAccountException(data['error'].toString());
      }
      return response.data;
    } catch (error) {
      if (error is SupabaseAccountException) rethrow;
      throw SupabaseAccountException(_friendlyFunctionError(error));
    }
  }

  AppUser _userFromFunctionResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final profile = data['profile'];
      if (profile is Map<String, dynamic>) return _userFromMap(profile);

      final account = data['account'];
      if (account is Map<String, dynamic>) return _userFromMap(account);

      final user = data['user'];
      if (user is Map<String, dynamic>) return _userFromMap(user);

      if (!data.containsKey('cargo')) {
        throw SupabaseAccountException(
          'A função manage-account não devolveu profile nem account. Resposta recebida: $data',
        );
      }
      return _userFromMap(data);
    }
    throw const SupabaseAccountException(
      'Resposta inválida da função de gestão de contas.',
    );
  }

  AppUser? _firstUserFromRows(dynamic rows) {
    final users = _usersFromRows(rows);
    return users.isEmpty ? null : users.first;
  }

  List<AppUser> _usersFromRows(dynamic rows) {
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_userFromMap)
        .toList(growable: false);
  }

  AppUser _userFromMap(Map<String, dynamic> row) {
    final cargo = _stringValue(row, 'cargo');
    if (cargo.isEmpty) {
      throw const SupabaseAccountException(
        'Perfil profissional incompleto. O campo cargo está vazio.',
      );
    }

    final role = AppRole.fromSupabaseCargo(cargo);
    if (role == null) {
      throw SupabaseAccountException(
        'Cargo inválido recebido do Supabase: $cargo.',
      );
    }

    final createdAtValue = _stringValue(row, 'created_at');
    return AppUser(
      userId: _stringValue(
        row,
        'auth_user_id',
        fallback: _stringValue(row, 'user_id'),
      ),
      name: _stringValue(row, 'nome'),
      email: _stringValue(row, 'email').toLowerCase(),
      role: role,
      hospitalId:
          _nullableStringValue(row, 'hospital') ??
          _nullableStringValue(row, 'hospital_id'),
      active: _boolValue(row, 'ativo', fallback: true),
      department: _stringValue(row, 'departamento', fallback: 'Não definido'),
      createdBy: _stringValue(row, 'created_by'),
      createdAt: DateTime.tryParse(createdAtValue),
    );
  }

  String _friendlyFunctionError(Object error) {
    final raw = error.toString();
    final functionErrorMatch = RegExp(r'error:\s*([^},]+)').firstMatch(raw);
    if (functionErrorMatch != null) {
      return functionErrorMatch.group(1)!.trim();
    }
    if (raw.contains('401') || raw.contains('403')) {
      return 'A tua sessão não tem permissão para gerir contas no Supabase.';
    }
    if (raw.contains('404') || raw.contains('manage-account')) {
      return 'A função Supabase manage-account ainda não está publicada.';
    }
    if (raw.toLowerCase().contains('failed host lookup') ||
        raw.toLowerCase().contains('socketexception')) {
      return 'Não foi possível ligar ao Supabase. Verifica a internet e o URL do projeto.';
    }
    return 'Erro ao sincronizar conta no Supabase: $raw';
  }

  String _normalizedDepartment(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Não definido' : trimmed;
  }

  String _cargoForRole(AppRole role) {
    return switch (role) {
      AppRole.superAdmin => 'super_admin',
      AppRole.adminHospital => 'admin',
      AppRole.medico => 'medico',
      AppRole.enfermeiro => 'enfermeiro',
      AppRole.tecnicoEmergencia => 'tecnico',
      AppRole.administrativo => 'rececionista',
      AppRole.triagem => 'triagem',
      AppRole.diretorClinico => 'medico',
      AppRole.chefeEnfermagem => 'enfermeiro',
      AppRole.auxiliar => 'rececionista',
    };
  }

  String _stringValue(
    Map<String, dynamic> row,
    String key, {
    String fallback = '',
  }) {
    final value = row[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String? _nullableStringValue(Map<String, dynamic> row, String key) {
    final value = _stringValue(row, key);
    return value.isEmpty ? null : value;
  }

  bool _boolValue(
    Map<String, dynamic> row,
    String key, {
    required bool fallback,
  }) {
    final value = row[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }
}

const supabaseAccountService = SupabaseAccountService();
