import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'state.dart';

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error));
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Inline error banner so errors stay visible (not only in a transient snackbar).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      );
}

/// Calls [load] now and then every [interval] (seat counts refresh without any manual reload).
mixin Polling<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  void startPolling(Future<void> Function() load, Duration interval) {
    load();
    _timer = Timer.periodic(interval, (_) => load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final TextEditingController _student;

  @override
  void initState() {
    super.initState();
    _student = TextEditingController(text: context.read<AppState>().studentInput);
  }

  void openHold(String holdId) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicationScreen(holdId: holdId)));

  Future<void> _settings() async {
    final app = context.read<AppState>();
    final c = TextEditingController(text: app.api.baseUrl);
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Server address'),
              content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Backend URL')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      app.setApiUrl(c.text);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pages = [
      ClassListScreen(onOpenHold: openHold),
      MyApplicationsScreen(onOpenHold: openHold),
      const CreateClassScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Admission'),
        actions: [IconButton(tooltip: 'Server address', onPressed: _settings, icon: const Icon(Icons.settings))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _student,
            keyboardType: TextInputType.number,
            maxLength: 17,
            onChanged: app.setStudent,
            decoration: InputDecoration(
              labelText: 'Student birth registration number (17 digits)',
              border: const OutlineInputBorder(),
              errorText: app.studentError,
              counterText: '',
            ),
          ),
        ),
        Expanded(child: pages[_tab]),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'My applications'),
          NavigationDestination(icon: Icon(Icons.add_box), label: 'Create class'),
        ],
      ),
    );
  }
}

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key, required this.onOpenHold});
  final void Function(String holdId) onOpenHold;
  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> with Polling {
  List<ClassInfo>? _classes;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    startPolling(_load, const Duration(seconds: 3));
  }

  Future<void> _load() async {
    try {
      final c = await context.read<AppState>().api.listClasses();
      if (mounted) setState(() { _classes = c; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _apply(ClassInfo c) async {
    final app = context.read<AppState>();
    if (app.student == null) {
      showError(context, 'Please enter a valid 17-digit birth registration number at the top first.');
      return;
    }
    setState(() => _busy = c.id);
    try {
      final hold = await app.api.apply(c.id, app.student!);
      if (mounted) widget.onOpenHold(hold.holdId);
    } catch (e) {
      if (mounted) showError(context, 'Could not apply to "${c.name}": $e');
    } finally {
      if (mounted) setState(() => _busy = null);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = _classes;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) ErrorBanner(_error!),
        if (classes == null && _error == null) const Center(child: CircularProgressIndicator()),
        if (classes != null && classes.isEmpty) const Text('No classes yet. Ask the school admin to create one.'),
        for (final c in classes ?? <ClassInfo>[])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Total ${c.totalSeats} · On hold ${c.heldSeats} · Confirmed ${c.confirmedSeats}'),
                Text('Available: ${c.availableSeats}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: (c.availableSeats == 0 || _busy == c.id) ? null : () => _apply(c),
                  child: Text(c.availableSeats == 0 ? 'Full' : (_busy == c.id ? 'Applying…' : 'Apply')),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

Color statusColor(String s) => switch (s) {
      'CONFIRMED' => Colors.green.shade700,
      'HELD' => Colors.orange.shade800,
      _ => Colors.red.shade700,
    };

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key, required this.onOpenHold});
  final void Function(String holdId) onOpenHold;
  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> with Polling {
  List<Hold>? _holds;
  String? _error;

  @override
  void initState() {
    super.initState();
    startPolling(_load, const Duration(seconds: 4));
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    if (app.student == null) {
      if (mounted) setState(() { _holds = null; _error = null; });
      return;
    }
    try {
      final h = await app.api.myHolds(app.student!);
      if (mounted) setState(() { _holds = h; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final holds = _holds;
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (app.student == null)
          const ErrorBanner('Enter your 17-digit birth registration number at the top to see your applications.'),
        if (_error != null) ErrorBanner(_error!),
        if (app.student != null && holds != null && holds.isEmpty)
          const Text('You have no applications yet. Go to Classes and apply.'),
        for (final h in holds ?? <Hold>[])
          Card(
            child: ListTile(
              title: Text(h.className ?? h.classId),
              subtitle: Text(h.effectiveStatus(now), style: TextStyle(color: statusColor(h.effectiveStatus(now)), fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpenHold(h.holdId),
            ),
          ),
      ]),
    );
  }
}

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});
  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _name = TextEditingController();
  final _seats = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final seats = int.tryParse(_seats.text.trim());
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Please enter a class name, for example "Class 6 - Morning Shift".');
    if (seats == null || seats < 1) return setState(() => _error = 'Total seats must be a whole number of at least 1.');
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().api.createClass(_name.text.trim(), seats);
      _name.clear();
      _seats.clear();
      if (mounted) showOk(context, 'Class created.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Create a class (school admin)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_error != null) ErrorBanner(_error!),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Class name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: _seats,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total seats', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating…' : 'Create class')),
      ]);
}

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key, required this.holdId});
  final String holdId;
  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> with Polling {
  Hold? _hold;
  String? _error, _notice;
  bool _busy = false;
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    startPolling(_load, const Duration(seconds: 3));
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final wasHeld = _hold?.effectiveStatus(_now) == 'HELD';
      setState(() => _now = DateTime.now());
      // Countdown just hit zero: ask the server right away.
      if (wasHeld && _hold?.effectiveStatus(_now) == 'EXPIRED') _load();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final h = await context.read<AppState>().api.getHold(widget.holdId);
      if (mounted) setState(() { _hold = h; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _act(Future<void> Function(ApiClient, String) fn, String okMsg) async {
    final app = context.read<AppState>();
    if (app.student == null) {
      showError(context, 'Enter your 17-digit birth registration number on the main screen first.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await fn(app.api, app.student!);
      if (mounted) setState(() => _notice = okMsg);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hold;
    final status = h?.effectiveStatus(_now);
    final left = h == null ? Duration.zero : h.expiresAt.difference(_now.toUtc());
    final secs = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final active = status == 'HELD';
    return Scaffold(
      appBar: AppBar(title: const Text('Your application')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) ErrorBanner(_error!),
        if (h == null && _error == null) const Center(child: CircularProgressIndicator()),
        if (h != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Application ${h.holdId}'),
                const SizedBox(height: 8),
                Text(status!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: statusColor(status))),
                const SizedBox(height: 4),
                Text(switch (status) {
                  'HELD' => 'On hold – pay the admission fee to keep your seat',
                  'CONFIRMED' => 'Admission confirmed',
                  'EXPIRED' => 'Expired – the time ran out and the seat was released',
                  _ => 'Cancelled',
                }),
                if (active) ...[
                  const SizedBox(height: 8),
                  Text('Time left: ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  FilledButton(
                    onPressed: (!active || _busy) ? null : () => _act((a, s) => a.confirm(h.holdId, s), 'Payment received. Your admission is confirmed!'),
                    child: const Text('Pay admission fee'),
                  ),
                  OutlinedButton(
                    onPressed: (!active || _busy) ? null : () => _act((a, s) => a.cancel(h.holdId, s), 'Your application was cancelled and the seat was released.'),
                    child: const Text('Cancel'),
                  ),
                ]),
              ]),
            ),
          ),
        if (_notice != null && _error == null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_notice!, style: TextStyle(color: Colors.green.shade800))),
      ]),
    );
  }
}
