import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return ScaffoldPage(
      header: const PageHeader(title: Text('Settings')),
      content: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("Appearance", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Theme Flavor (The new stuff)
          Expander(
            header: const Text("Theme Flavor"),
            leading: const Icon(FluentIcons.color_solid),
            initiallyExpanded: true,
            content: Column(
              children: [
                _buildFlavorRadio(appState, ThemeFlavor.standard, "Standard Glass", "Default Windows 11 Mica effect"),
                const SizedBox(height: 8),
                _buildFlavorRadio(appState, ThemeFlavor.pitchBlack, "Pitch Black", "Total void. No glass. High contrast."),
                const SizedBox(height: 8),
                _buildFlavorRadio(appState, ThemeFlavor.ocean, "Ocean Depth", "Deep blue tinted glass."),
                const SizedBox(height: 8),
                _buildFlavorRadio(appState, ThemeFlavor.forest, "Cyber Forest", "Emerald tinted glass."),
              ],
            ),
          ),

          const SizedBox(height: 12),
          
          // Theme Mode
          Expander(
            header: const Text("Brightness"),
            leading: const Icon(FluentIcons.brightness),
            initiallyExpanded: false,
            content: Column(
              children: [
                RadioButton(
                  checked: appState.themeMode == ThemeMode.system,
                  onChanged: (v) => v == true ? appState.setThemeMode(ThemeMode.system) : null,
                  content: const Text("System Default"),
                ),
                const SizedBox(height: 8),
                RadioButton(
                  checked: appState.themeMode == ThemeMode.dark,
                  onChanged: (v) => v == true ? appState.setThemeMode(ThemeMode.dark) : null,
                  content: const Text("Dark"),
                ),
                const SizedBox(height: 8),
                RadioButton(
                  checked: appState.themeMode == ThemeMode.light,
                  onChanged: (v) => v == true ? appState.setThemeMode(ThemeMode.light) : null,
                  content: const Text("Light"),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),

          // Glass Effect Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FluentTheme.of(context).resources.cardStrokeColorDefault),
            ),
            child: Row(
              children: [
                const Icon(FluentIcons.blur),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Glass Effect (Mica)", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Disable this for solid colors (Performance++).", style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                ToggleSwitch(
                  // Pitch Black forces glass off, so disable toggle if Pitch Black is active
                  onChanged: appState.flavor == ThemeFlavor.pitchBlack ? null : appState.toggleGlass,
                  checked: appState.useGlass,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlavorRadio(AppState state, ThemeFlavor flavor, String title, String subtitle) {
    return RadioButton(
      checked: state.flavor == flavor,
      onChanged: (v) => v == true ? state.setThemeFlavor(flavor) : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}