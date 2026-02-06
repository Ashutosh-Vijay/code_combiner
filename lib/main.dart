import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

import 'logic/app_state.dart';
import 'pages/shell_page.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
      defaultTargetPlatform == TargetPlatform.linux || 
      defaultTargetPlatform == TargetPlatform.macOS)) {
    await Window.initialize();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await Window.setEffect(
        effect: WindowEffect.mica, 
        dark: true,
      );
    }
  }

  await SystemTheme.accentColor.load();

  // Initialize State (Load settings)
  final appState = AppState();
  await appState.loadSettings();

  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  final AppState appState;
  const MyApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return FluentApp(
            title: 'Code Combiner',
            themeMode: state.themeMode, 
            debugShowCheckedModeBanner: false,
            darkTheme: AppTheme.getTheme(Brightness.dark, state.useGlass, state.flavor),
            theme: AppTheme.getTheme(Brightness.light, state.useGlass, state.flavor),
            home: const ShellPage(),
          );
        },
      ),
    );
  }
}