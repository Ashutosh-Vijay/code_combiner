import 'package:fluent_ui/fluent_ui.dart';
import 'home_page.dart';
import 'utils_page.dart';
import 'settings_page.dart';
import 'exclusions_page.dart'; 
import 'about_page.dart'; // Import About

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int topIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        selected: topIndex,
        onChanged: (index) => setState(() => topIndex = index),
        displayMode: PaneDisplayMode.compact,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.code),
            title: const Text("Combiner"),
            body: const HomePage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.toolbox),
            title: const Text("Utilities"),
            body: const UtilsPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.filter),
            title: const Text("Exclusions"),
            body: ExclusionsPage(),
          ),
        ],
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text("Settings"),
            body: const SettingsPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.info),
            title: const Text("About"),
            body: const AboutPage(),
          ),
        ],
      ),
    );
  }
}