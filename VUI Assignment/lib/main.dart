import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vui/vui_theme.dart';
import 'vui/vui_state_manager.dart';
import 'screens/vui_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VuiMentalHealthApp());
}

class VuiMentalHealthApp extends StatelessWidget {
  const VuiMentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VuiStateManager()),
      ],
      child: MaterialApp(
        title: 'Sera VUI Mental Health App',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: VuiTheme.darkTheme,
        home: const VuiScreen(),
      ),
    );
  }
}
