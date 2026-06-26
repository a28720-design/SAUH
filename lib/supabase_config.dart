import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vital_signs_simulator.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

VitalSignsPersistence vitalSignsPersistence = LocalDemoVitalSignsPersistence();

bool get hasSupabaseCredentials =>
    supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

Future<void> configureSupabasePersistence() async {
  if (!hasSupabaseCredentials) {
    debugPrint('Supabase não configurado. A usar persistência local.');
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    vitalSignsPersistence = SupabaseVitalSignsPersistence(
      Supabase.instance.client,
    );
  } catch (error) {
    debugPrint('Falha ao inicializar Supabase: $error');
    vitalSignsPersistence = LocalDemoVitalSignsPersistence();
  }
}
