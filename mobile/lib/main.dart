import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'screens.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(ApiClient(defaultApiUrl()));
  await state.load();
  runApp(ChangeNotifierProvider.value(value: state, child: const SchoolApp()));
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'School Admission',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF0B5CAD), useMaterial3: true),
        home: const HomeScreen(),
      );
}
