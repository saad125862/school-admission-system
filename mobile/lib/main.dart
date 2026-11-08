import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'screens.dart';
import 'state.dart';
import 'theme.dart';

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
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: context.select<AppState, ThemeMode>((s) => s.themeMode),
        home: const HomeScreen(),
      );
}
