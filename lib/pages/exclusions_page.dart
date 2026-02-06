import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../logic/app_state.dart';

class ExclusionsPage extends StatefulWidget {
  const ExclusionsPage({super.key});

  @override
  State<ExclusionsPage> createState() => _ExclusionsPageState();
}

class _ExclusionsPageState extends State<ExclusionsPage> {
  final TextEditingController _folderCtrl = TextEditingController();
  final TextEditingController _patternCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Exclusions'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.reset),
              label: const Text('Reset to Defaults'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Reset Exclusions?'),
                    content: const Text('This will delete all your custom excluded folders, files, and patterns. This cannot be undone.'),
                    actions: [
                      Button(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                      FilledButton(
                        child: const Text('Reset'), 
                        onPressed: () {
                          appState.resetExclusionsToDefault();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LEFT COLUMN: FOLDERS ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ignored Folders", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Exact folder names to skip (e.g. node_modules)", style: TextStyle(fontSize: 11, color: theme.resources.textFillColorSecondary)),
                  const SizedBox(height: 12),
                  
                  // Add Input & Browse
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _folderCtrl,
                          placeholder: "Folder name...",
                          onSubmitted: (v) => _addFolder(appState),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // MANUAL ADD
                      IconButton(
                        icon: const Icon(FluentIcons.add),
                        onPressed: () => _addFolder(appState),
                      ),
                      const SizedBox(width: 8),
                      // BROWSE BUTTON
                      Tooltip(
                        message: "Browse to exclude a folder",
                        child: Button(
                          onPressed: () => appState.pickExcludedFolder(),
                          child: const Icon(FluentIcons.folder_open),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.resources.cardStrokeColorDefault),
                        borderRadius: BorderRadius.circular(4),
                        color: theme.cardColor,
                      ),
                      child: ListView.builder(
                        itemCount: appState.excludedFolderNames.length,
                        itemBuilder: (ctx, i) {
                          final item = appState.excludedFolderNames[i];
                          // SAFETY CHECK: Is this a default?
                          final isDefault = AppState.defaultFolders.contains(item);
                          
                          return ListTile(
                            title: Text(
                              item, 
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                color: isDefault ? theme.resources.textFillColorSecondary : null
                              )
                            ),
                            trailing: isDefault 
                              ? Tooltip(
                                  message: "Default Exclusion (Locked)",
                                  child: Icon(FluentIcons.lock, size: 12, color: theme.resources.textFillColorTertiary)
                                )
                              : IconButton(
                                  icon: const Icon(FluentIcons.delete, size: 12),
                                  onPressed: () => appState.removeExcludedFolder(item),
                                ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 24),

            // --- RIGHT COLUMN: PATTERNS & FILES ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ignored Patterns & Files", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Patterns (*.log) or specific files.", style: TextStyle(fontSize: 11, color: theme.resources.textFillColorSecondary)),
                  const SizedBox(height: 12),

                  // Add Input
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _patternCtrl,
                          placeholder: "*.ext",
                          onSubmitted: (v) => _addPattern(appState),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(FluentIcons.add),
                        onPressed: () => _addPattern(appState),
                      ),
                      const SizedBox(width: 8),
                      // BROWSE FILE BUTTON
                      Tooltip(
                        message: "Pick specific file to exclude",
                        child: Button(
                          onPressed: () => appState.pickExcludedFile(),
                          child: const Icon(FluentIcons.document),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List (Patterns + Files)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.resources.cardStrokeColorDefault),
                        borderRadius: BorderRadius.circular(4),
                        color: theme.cardColor,
                      ),
                      child: ListView(
                        children: [
                          // Section: Files (User added, always deletable) -- NOW ON TOP
                          if (appState.excludedFiles.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("SPECIFIC FILES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            ...appState.excludedFiles.map((item) => ListTile(
                              title: Text(p.basename(item), style: const TextStyle(fontFamily: 'Consolas')),
                              subtitle: Text(item, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(FluentIcons.delete, size: 12),
                                onPressed: () => appState.removeExcludedFile(item),
                              ),
                            )),
                          ],

                          // Section: Patterns
                          if (appState.excludedPatterns.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("PATTERNS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            ...appState.excludedPatterns.map((item) {
                              final isDefault = AppState.defaultPatterns.contains(item);
                              return ListTile(
                                title: Text(
                                  item, 
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    color: isDefault ? theme.resources.textFillColorSecondary : null
                                  )
                                ),
                                trailing: isDefault 
                                  ? Tooltip(
                                      message: "Default Exclusion (Locked)",
                                      child: Icon(FluentIcons.lock, size: 12, color: theme.resources.textFillColorTertiary)
                                    )
                                  : IconButton(
                                      icon: const Icon(FluentIcons.delete, size: 12),
                                      onPressed: () => appState.removeExcludedPattern(item),
                                    ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.resources.cardStrokeColorDefault)),
          color: theme.navigationPaneTheme.backgroundColor,
        ),
        child: ToggleSwitch(
          checked: appState.useGitIgnore,
          onChanged: appState.toggleGitIgnore,
          content: const Text("Respect .gitignore rules"),
        ),
      ),
    );
  }

  void _addFolder(AppState state) {
    if (_folderCtrl.text.isNotEmpty) {
      state.addExcludedFolder(_folderCtrl.text.trim());
      _folderCtrl.clear();
    }
  }

  void _addPattern(AppState state) {
    if (_patternCtrl.text.isNotEmpty) {
      state.addExcludedPattern(_patternCtrl.text.trim());
      _patternCtrl.clear();
    }
  }
}