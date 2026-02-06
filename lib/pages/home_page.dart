import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../logic/app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDragging = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = FluentTheme.of(context);

    // Context Logic
    const int maxSafeTokens = 32000; 
    final double tokenUsage = (appState.totalTokens / maxSafeTokens).clamp(0.0, 1.0);
    
    Color budgetColor = Colors.green;
    if (tokenUsage > 0.5) budgetColor = Colors.orange;
    if (tokenUsage > 0.8) budgetColor = Colors.red;

    return DropTarget(
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          final path = details.files.first.path;
          if (FileSystemEntity.isDirectorySync(path)) {
            appState.setPathFromDrop(path);
          }
        }
      },
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Stack(
          children: [
            // FIXED: Positioned.fill ensures the Column gets tight constraints (Screen Size)
            // This prevents "RenderBox was not laid out" in the LayoutBuilder.
            Positioned.fill(
              child: Column(
                children: [
                  // --- 1. CLEAN TOOLBAR ---
                  Container(
                    height: 60,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                      border: Border(bottom: BorderSide(color: theme.resources.cardStrokeColorDefault.withValues(alpha: 0.2))),
                    ),
                    child: Row(
                      children: [
                        // Config Pills
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: theme.resources.controlFillColorTertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropDownButton(
                            title: Text(
                              appState.projectType.name.toUpperCase(), 
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                            ),
                            items: ProjectType.values.map((e) => MenuFlyoutItem(
                              text: Text(e.name.toUpperCase()),
                              onPressed: () => appState.setProjectType(e),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // FORMAT SELECTOR
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: theme.resources.controlFillColorTertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropDownButton(
                            title: Text(
                              "FMT: ${appState.outputFormat.name.toUpperCase()}", 
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                            ),
                            items: OutputFormat.values.map((e) => MenuFlyoutItem(
                              text: Text(e.name.toUpperCase()),
                              onPressed: () => appState.setOutputFormat(e),
                            )).toList(),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Address Bar
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: theme.resources.controlFillColorSecondary,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: theme.resources.cardStrokeColorDefault.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(FluentIcons.folder_open, size: 14, color: theme.resources.textFillColorSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appState.selectedPath ?? "Drag folder here...",
                                    style: TextStyle(
                                      fontFamily: 'Consolas', 
                                      fontSize: 12, 
                                      color: appState.selectedPath == null 
                                        ? theme.resources.textFillColorTertiary 
                                        : theme.resources.textFillColorPrimary
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (appState.selectedPath != null)
                                  IconButton(
                                    icon: const Icon(FluentIcons.edit, size: 12),
                                    onPressed: appState.pickFolder,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // SEARCH BAR
                        SizedBox(
                          width: 200,
                          height: 32,
                          child: TextBox(
                            controller: _searchCtrl,
                            placeholder: 'Search files...',
                            onChanged: (v) => appState.setSearchFilter(v),
                            suffix: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(FluentIcons.clear, size: 10),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      appState.setSearchFilter("");
                                    },
                                  )
                                : const Icon(FluentIcons.search, size: 12),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- 2. MAIN CONTENT AREA ---
                  Expanded(
                    child: appState.files.isEmpty 
                      ? _buildEmptyState(theme)
                      : Container(
                          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.3),
                          child: Column(
                            children: [
                              // List Headers
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: theme.resources.cardStrokeColorDefault.withValues(alpha: 0.1))),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: Checkbox(
                                        checked: appState.selectedCount == appState.files.length && appState.files.isNotEmpty 
                                            ? true 
                                            : (appState.selectedCount == 0 ? false : null),
                                        onChanged: (v) {
                                          appState.toggleAllFiles(v == true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text("NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.resources.textFillColorTertiary)),
                                    
                                    const SizedBox(width: 12),
                                    
                                    // RELOAD BUTTON
                                    Tooltip(
                                      message: "Refresh file list",
                                      child: IconButton(
                                        icon: Icon(FluentIcons.refresh, size: 12, color: theme.accentColor),
                                        onPressed: appState.isScanning ? null : appState.scanFiles,
                                      ),
                                    ),

                                    const Spacer(),
                                    Text("SIZE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.resources.textFillColorTertiary)),
                                    const SizedBox(width: 60), 
                                  ],
                                ),
                              ),
                              // List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: appState.filteredFiles.length,
                                  itemBuilder: (ctx, i) {
                                    final file = appState.filteredFiles[i];
                                    return HoverButton(
                                      onPressed: () => appState.toggleFileSelection(file, !file.isSelected),
                                      builder: (context, states) {
                                        return Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          color: states.isHovered 
                                            ? theme.resources.subtleFillColorSecondary 
                                            : Colors.transparent,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                child: Checkbox(
                                                  checked: file.isSelected,
                                                  onChanged: (v) => appState.toggleFileSelection(file, v ?? false),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                file.type == FileType.binary ? FluentIcons.database : FluentIcons.file_code,
                                                size: 14,
                                                color: file.type == FileType.binary 
                                                  ? Colors.orange.withValues(alpha: 0.8) 
                                                  : Colors.blue.withValues(alpha: 0.8),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  file.path.replaceFirst(appState.selectedPath ?? '', '.'), 
                                                  style: TextStyle(
                                                    fontFamily: 'Consolas',
                                                    color: file.isSelected 
                                                      ? theme.resources.textFillColorPrimary 
                                                      : theme.resources.textFillColorTertiary,
                                                    decoration: file.isSelected ? null : TextDecoration.lineThrough,
                                                    fontSize: 12
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                file.statString, 
                                                style: TextStyle(fontSize: 11, fontFamily: 'Consolas', color: theme.resources.textFillColorSecondary)
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 50,
                                                child: Text(
                                                  "${file.estimatedTokens}", 
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(fontSize: 10, color: theme.resources.textFillColorTertiary)
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),

                  // --- 3. STATUS BAR (Fixed Safe Layout) ---
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: (theme.navigationPaneTheme.backgroundColor ?? Colors.black).withValues(alpha: 0.95), 
                      border: Border(top: BorderSide(color: theme.resources.cardStrokeColorDefault.withValues(alpha: 0.2))),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // FIX: Safe constraints to prevent RenderBox crash on infinite width
                        final double safeWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 1000.0;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: safeWidth),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min, // FIXED: Changed max back to min. Row inside ScrollView must be min to allow expansion but not infinity.
                                children: [
                                  _buildLeftStats(appState, theme),
                                  const SizedBox(width: 24), // Explicit gap
                                  _buildRightActions(appState, theme, budgetColor, context),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            if (_isDragging)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.cloud_download, size: 48, color: theme.accentColor),
                      const SizedBox(height: 16),
                      Text("DROP TO SCAN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Extracted Widgets to keep build method clean and reusable for both layouts
  Widget _buildLeftStats(AppState appState, FluentThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.hard_drive, size: 12, color: theme.resources.textFillColorTertiary),
        const SizedBox(width: 8),
        Text(
          "${appState.selectedCount} selected", 
          style: TextStyle(fontSize: 11, color: theme.resources.textFillColorSecondary)
        ),
        const SizedBox(width: 16),
        Text(
          appState.totalSize, 
          style: TextStyle(fontSize: 11, fontFamily: 'Consolas', fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  Widget _buildRightActions(AppState appState, FluentThemeData theme, Color budgetColor, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (appState.isScanning) 
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(width: 12, height: 12, child: ProgressRing(strokeWidth: 2)),
          ),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: budgetColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: budgetColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.lightning_bolt, size: 10, color: budgetColor),
              const SizedBox(width: 6),
              Text(
                "${appState.totalTokens} toks", 
                style: TextStyle(fontSize: 11, fontFamily: 'Consolas', color: budgetColor, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),

        Button(
          onPressed: appState.selectedCount == appState.files.length 
              ? null 
              : () => appState.excludeUnselectedFiles(),
          child: const Row(
            children: [
              Icon(FluentIcons.remove_occurrence, size: 12),
              SizedBox(width: 6),
              Text("Exclude Unselected"),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Button(
          onPressed: appState.files.isEmpty ? null : () => appState.copyFileTree(context),
          child: const Row(
            children: [
              Icon(FluentIcons.org, size: 12),
              SizedBox(width: 6),
              Text("Copy Tree"),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Button(
          onPressed: appState.files.isEmpty ? null : () => appState.generateOutput(context),
          child: const Text("Save File"),
        ),
        
        const SizedBox(width: 8),

        FilledButton(
          onPressed: appState.files.isEmpty ? null : () => appState.copyToClipboard(context),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
            backgroundColor: WidgetStateProperty.all(theme.accentColor),
          ),
          child: Row(
            children: [
              if (appState.isProcessing)
                const SizedBox(width: 12, height: 12, child: ProgressRing(strokeWidth: 2, activeColor: Colors.white))
              else
                const Icon(FluentIcons.copy, size: 12),
              const SizedBox(width: 6),
              Text(
                appState.isProcessing ? "..." : "Copy Context", 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(FluentIcons.search_data, size: 48, color: theme.resources.textFillColorTertiary),
          ),
          const SizedBox(height: 24),
          Text(
            "No Context Loaded", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.resources.textFillColorPrimary)
          ),
          const SizedBox(height: 8),
          Text(
            "Drag a folder here or browse to begin", 
            style: TextStyle(fontSize: 12, color: theme.resources.textFillColorSecondary)
          ),
          const SizedBox(height: 24),
          Button(
            onPressed: () => context.read<AppState>().pickFolder(),
            child: const Text("Browse Files"),
          )
        ],
      ),
    );
  }
}