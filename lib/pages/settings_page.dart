import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../logic/app_state.dart';
import '../theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // Determine effective brightness to lock down UI
    final isLightMode = FluentTheme.of(context).brightness == Brightness.light;
    final isPitchBlack = appState.flavor == ThemeFlavor.pitchBlack;
    // New: Check if we are using a Tinted Glass theme (Ocean/Forest)
    final isTintedGlass = appState.flavor == ThemeFlavor.ocean || appState.flavor == ThemeFlavor.forest;

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
                _buildFlavorRadio(
                  appState, 
                  ThemeFlavor.standard, 
                  "Standard", 
                  "Default Glass / Solid",
                  enabled: true // Always available
                ),
                const SizedBox(height: 8),
                _buildFlavorRadio(
                  appState, 
                  ThemeFlavor.pitchBlack, 
                  "Pitch Black", 
                  "Total void. OLED Friendly.",
                  enabled: !isLightMode // Disable in Light Mode
                ),
                const SizedBox(height: 8),
                _buildFlavorRadio(
                  appState, 
                  ThemeFlavor.ocean, 
                  "Ocean Depth", 
                  "Deep blue tinted glass (Forces Glass ON).",
                  enabled: !isLightMode // Disable in Light Mode
                ),
                const SizedBox(height: 8),
                _buildFlavorRadio(
                  appState, 
                  ThemeFlavor.forest, 
                  "Cyber Forest", 
                  "Emerald tinted glass (Forces Glass ON).",
                  enabled: !isLightMode // Disable in Light Mode
                ),
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
                  onChanged: (v) {
                    if (v == true) {
                      appState.setThemeMode(ThemeMode.light);
                      // Auto-revert to Standard if on a restricted flavor
                      if (appState.flavor != ThemeFlavor.standard) {
                        appState.setThemeFlavor(ThemeFlavor.standard);
                      }
                    }
                  },
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
                Icon(
                  FluentIcons.blur, 
                  // Grey out icon if the setting is locked (Pitch Black OR Tinted Glass)
                  color: (isPitchBlack || isTintedGlass) ? Colors.grey : null
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Glass Effect (Mica)", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // Grey out text if locked
                          color: (isPitchBlack || isTintedGlass) ? Colors.grey : null
                        )
                      ),
                      Text(
                        // Dynamic description based on why it's locked
                        isPitchBlack 
                            ? "Disabled in Pitch Black mode." 
                            : isTintedGlass 
                                ? "Required for this theme flavor." 
                                : "Makes the window background translucent.", 
                        style: const TextStyle(fontSize: 11)
                      ),
                    ],
                  ),
                ),
                ToggleSwitch(
                  // FIXED: Disable interaction if Pitch Black OR Tinted Glass (Ocean/Forest)
                  // If it's Standard, you can toggle. Otherwise, it's locked.
                  onChanged: (isPitchBlack || isTintedGlass) ? null : appState.toggleGlass,
                  // Ensure visual state matches reality
                  checked: appState.useGlass,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlavorRadio(AppState state, ThemeFlavor flavor, String title, String subtitle, {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: RadioButton(
        checked: state.flavor == flavor,
        // Disable click if not enabled
        onChanged: enabled ? (v) {
          if (v == true) state.setThemeFlavor(flavor);
        } : null,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}