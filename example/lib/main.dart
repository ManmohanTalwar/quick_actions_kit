import 'package:dartnative/dartnative.dart';
import 'package:quick_actions_kit/quick_actions_kit.dart';
import 'dartnative_plugin_registrant.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const QuickActionsDemo());
}

class QuickActionsDemo extends StatefulWidget {
  const QuickActionsDemo({super.key});
  @override
  State<QuickActionsDemo> createState() => _QuickActionsDemoState();
}

class _QuickActionsDemoState extends State<QuickActionsDemo> {
  final _actions = QuickActions();
  String _status = 'Starting…';
  int _activations = 0;
  String _lastActivation = 'None';
  @override
  void initState() {
    super.initState();
    _run(
      () => _actions.initialize((type) {
        if (mounted) {
          setState(() {
            _activations++;
            _lastActivation = type;
          });
        }
      }),
      'Ready. Install shortcuts, then long-press this app on the home screen.',
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) setState(() => _status = success);
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    }
  }

  @override
  void dispose() {
    // This demo owns the singleton for its entire mounted lifetime.
    _actions.dispose().catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quick actions')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(_status),
          Text('Activations: $_activations'),
          Text('Last action: $_lastActivation'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _run(
              () => _actions.setShortcutItems([
                const ShortcutItem(
                  type: 'compose',
                  localizedTitle: 'New post',
                  localizedSubtitle: 'Open the composer',
                ),
                const ShortcutItem(type: 'search', localizedTitle: 'Search'),
                const ShortcutItem(
                  type: 'unicode_📝',
                  localizedTitle: 'नया पोस्ट 📝',
                ),
              ]),
              'Three shortcuts installed.',
            ),
            child: const Text('Install shortcuts'),
          ),
          ElevatedButton(
            onPressed: () =>
                _run(_actions.clearShortcutItems, 'Dynamic shortcuts cleared.'),
            child: const Text('Clear shortcuts'),
          ),
        ],
      ),
    ),
  );
}
