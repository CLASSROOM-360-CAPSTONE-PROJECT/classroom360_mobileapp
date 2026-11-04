import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final problem = Env.problem;
  if (problem == null) {
    // `anonKey` takes the publishable key too and exists in every supabase_flutter 2.x; newer 2.x
    // releases name the same thing `publishableKey` (the old name only gives a deprecation notice).
    // ignore: deprecated_member_use
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }
  runApp(Classroom360App(settingsProblem: problem));
}
