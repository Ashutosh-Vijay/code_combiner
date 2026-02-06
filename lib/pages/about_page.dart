import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    
    return ScaffoldPage(
      header: const PageHeader(title: Text('About')),
      content: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.resources.cardStrokeColorDefault),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo Placeholder
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.accentColor.withValues(alpha: 0.5), width: 2),
                ),
                child: Center(
                  child: Icon(FluentIcons.code, size: 40, color: theme.accentColor),
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                "Code Combiner", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.resources.cardStrokeColorDefault,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("v1.0.0 • God Mode", style: TextStyle(fontSize: 12)),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                "The ultimate context preparation tool for LLMs.\nStop pasting node_modules into ChatGPT.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              
              const SizedBox(height: 32),
              
              const Divider(),
              const SizedBox(height: 16),
              
              // Credits
              const Text("Created by", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text("Ashutosh Vijay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              
              const SizedBox(height: 24),
              
              // Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Button(
                    onPressed: () => _launchUrl("https://github.com/Ashutosh-Vijay"), 
                    child: const Row(
                      children: [
                        // FIXED: Used a safe generic icon since FluentIcons doesn't have brand logos
                        Icon(FluentIcons.link, size: 14), 
                        SizedBox(width: 8),
                        Text("GitHub"),
                      ],
                    ),
                  ),
                  // DELETED: Twitter button is gone.
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}