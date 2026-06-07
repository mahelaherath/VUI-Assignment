import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vui/vui_theme.dart';
import 'vui/vui_state_manager.dart';
import 'vui/navigation_notifier.dart';
import 'screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SeraApp());
}

class SeraApp extends StatelessWidget {
  const SeraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VuiStateManager()),
        ChangeNotifierProvider(create: (_) => NavigationNotifier()),
      ],
      child: MaterialApp(
        title: 'Sera',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: VuiTheme.darkTheme,
        home: const MainNavScreen(),
      ),
    );
  }
}
