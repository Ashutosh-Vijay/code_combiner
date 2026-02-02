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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return FluentApp(
            title: 'Code Combiner',
            themeMode: appState.themeMode, 
            debugShowCheckedModeBanner: false,
            // FIXED: Passing the selected FLAVOR to the theme engine
            darkTheme: AppTheme.getTheme(Brightness.dark, appState.useGlass, appState.flavor),
            theme: AppTheme.getTheme(Brightness.light, appState.useGlass, appState.flavor),
            home: const ShellPage(),
          );
        },
      ),
    );
  }
}