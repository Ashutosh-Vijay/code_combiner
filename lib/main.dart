import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart'; // The Frame Logic
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

  // 1. Initialize State & Load Brains (Settings)
  final appState = AppState();
  await appState.loadSettings(); 

  // 2. Pass the loaded brain to the app
  runApp(MyApp(appState: appState));
  
  // 3. Configure BitsDojo Window (The Custom Frame)
  doWhenWindowReady(() {
    const initialSize = Size(1000, 750);
    appWindow.minSize = const Size(600, 450);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "Code Combiner";
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  // 3. Store the state
  final AppState appState;
  
  const MyApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    // 4. Use .value to provide the EXISTING instance (not a new one)
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
            // Wrap the Shell in our Custom Window Frame
            home: const CustomWindowShell(child: ShellPage()),
          );
        },
      ),
    );
  }
}

// --- CUSTOM WINDOW SHELL ---
class CustomWindowShell extends StatelessWidget {
  final Widget child;
  const CustomWindowShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    // Determine button colors based on brightness
    final isDark = theme.brightness == Brightness.dark;
    
    // Window Button Colors (Platform Adaptive)
    final buttonColors = WindowButtonColors(
      iconNormal: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111),
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    final normalButtonColors = WindowButtonColors(
      iconNormal: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111),
      mouseOver: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
      mouseDown: isDark ? const Color(0xFF222222) : const Color(0xFFCCCCCC),
      iconMouseOver: isDark ? Colors.white : Colors.black,
      iconMouseDown: isDark ? Colors.white : Colors.black,
    );

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // --- CUSTOM TITLE BAR ---
          WindowTitleBarBox(
            child: Container(
              // Fully transparent background so Mica/Acrylic shows through
              color: Colors.transparent, 
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  // App Icon
                  Icon(FluentIcons.code, size: 14, color: theme.accentColor),
                  const SizedBox(width: 8),
                  // App Title
                  Text("Code Combiner", style: TextStyle(fontSize: 12, color: theme.resources.textFillColorSecondary)),
                  
                  const SizedBox(width: 16),
                  
                  // Drag Region (Expanded)
                  Expanded(
                    child: MoveWindow(
                      child: Container(
                        color: Colors.transparent, // Hit test target
                      ),
                    ),
                  ),

                  // Window Buttons (Min/Max/Close)
                  MinimizeWindowButton(colors: normalButtonColors),
                  MaximizeWindowButton(colors: normalButtonColors),
                  CloseWindowButton(colors: buttonColors),
                ],
              ),
            ),
          ),
          
          // --- APP CONTENT (Sidebar + Pages) ---
          Expanded(child: child),
        ],
      ),
    );
  }
}