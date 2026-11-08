import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: kDanger));
}

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Calls [load] now and then every [interval] (counts refresh without any manual reload).
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

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text(subtitle, style: t.bodySmall?.copyWith(color: muted, height: 1.35)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.title, this.text, {super.key});
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: muted.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(icon, size: 44, color: kPrimary2),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
      ]),
    );
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
                    style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final pages = <Widget>[
      ClassListScreen(key: const ValueKey('classes'), onOpenHold: openHold),
      MyApplicationsScreen(key: const ValueKey('mine'), onOpenHold: openHold),
      const CreateClassScreen(key: ValueKey('create')),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(gradient: kBrandGradient, borderRadius: BorderRadius.circular(13), boxShadow: [
                  BoxShadow(color: kPrimary2.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
                ]),
                child: const Icon(Icons.school_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('School Admission', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
                  Text('First come, first served', style: TextStyle(fontSize: 12, color: muted)),
                ]),
              ),
              IconButton(tooltip: 'Toggle theme', onPressed: () => app.toggleTheme(dark), icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
              IconButton(tooltip: 'Server address', onPressed: _settings, icon: const Icon(Icons.settings_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _student,
              keyboardType: TextInputType.number,
              maxLength: 17,
              onChanged: app.setStudent,
              decoration: InputDecoration(
                labelText: 'Student birth registration number',
                hintText: '17 digits',
                counterText: '',
                prefixIcon: const Icon(Icons.badge_outlined),
                errorText: app.studentError,
                suffixIcon: AnimatedScale(
                  scale: app.student != null ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: const Icon(Icons.check_circle_rounded, color: kOk),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim), child: child),
              ),
              child: pages[_tab],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'My applications'),
          NavigationDestination(icon: Icon(Icons.add_box_rounded), label: 'Create class'),
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        SectionHeader('Classes', 'Pick a class and shift. A seat is held while you pay.',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const _LiveDot(),
              const SizedBox(width: 6),
              Text('Live', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
            ])),
        if (_error != null) Banner2(_error!),
        if (classes == null && _error == null) ...[const Skeleton(height: 230), const Skeleton(height: 230)],
        if (classes != null && classes.isEmpty) const EmptyState(Icons.inbox_rounded, 'No classes yet', 'Ask the school admin to create one.'),
        for (var i = 0; i < (classes?.length ?? 0); i++)
          FadeSlideIn(
            key: ValueKey(classes![i].id),
            delay: Duration(milliseconds: 70 * i),
            child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _ClassCard(c: classes[i], busy: _busy == classes[i].id, onApply: () => _apply(classes[i]))),
          ),
      ]),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 16,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            Container(width: 16 * _c.value, height: 16 * _c.value, decoration: BoxDecoration(shape: BoxShape.circle, color: kOk.withValues(alpha: 0.35 * (1 - _c.value)))),
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: kOk)),
          ]),
        ),
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.c, required this.busy, required this.onApply});
  final ClassInfo c;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final full = c.availableSeats == 0;
    final few = !full && c.availableSeats / (c.totalSeats == 0 ? 1 : c.totalSeats) <= 0.1;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5))),
            if (full) _tag('Full', kDanger) else if (few) _tag('Few left', kWarn),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
              child: Text('${c.availableSeats}', key: ValueKey(c.availableSeats), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1.5)),
            ),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('seats available', style: TextStyle(color: muted, fontSize: 13))),
          ]),
          const SizedBox(height: 12),
          SeatMeter(confirmed: c.confirmedSeats, held: c.heldSeats, total: c.totalSeats),
          const SizedBox(height: 14),
          Row(children: [
            _stat(context, '${c.totalSeats}', 'Total', null),
            const SizedBox(width: 8),
            _stat(context, '${c.heldSeats}', 'On hold', kWarn),
            const SizedBox(width: 8),
            _stat(context, '${c.confirmedSeats}', 'Confirmed', kOk),
          ]),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (full || busy) ? null : onApply,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy) ...[const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)), const SizedBox(width: 10)],
              Text(full ? 'Full' : (busy ? 'Applying…' : 'Apply')),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
      );

  Widget _stat(BuildContext context, String value, String label, Color? dot) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Row(children: [
            if (dot != null) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 5)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12))),
          ]),
        ]),
      ),
    );
  }
}

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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const SectionHeader('My applications', 'Every application for this student, newest first.'),
        if (app.student == null) const Banner2('Enter your 17-digit birth registration number at the top to see your applications.'),
        if (_error != null) Banner2(_error!),
        if (app.student != null && holds == null && _error == null) const Skeleton(height: 84),
        if (app.student != null && holds != null && holds.isEmpty)
          const EmptyState(Icons.receipt_long_rounded, 'No applications yet', 'Go to Classes and apply for a seat.'),
        for (var i = 0; i < (holds?.length ?? 0); i++)
          FadeSlideIn(
            key: ValueKey(holds![i].holdId),
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onOpenHold(holds[i].holdId),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(holds[i].className ?? holds[i].classId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            holds[i].effectiveStatus(now) == 'HELD' ? 'Hold expires ${TimeOfDay.fromDateTime(holds[i].expiresAt.toLocal()).format(context)}' : 'Application ${holds[i].holdId}',
                            style: TextStyle(color: muted, fontSize: 12.5),
                          ),
                        ]),
                      ),
                      StatusPill(holds[i].effectiveStatus(now)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ]),
                  ),
                ),
              ),
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
  static const _presets = ['Class 6 - Morning Shift', 'Class 6 - Day Shift', 'Class 7 - Morning Shift', 'Class 8 - Day Shift'];
  final _name = TextEditingController();
  final _seats = TextEditingController();
  String? _error;
  String? _ok;
  bool _busy = false;

  Future<void> _submit() async {
    final seats = int.tryParse(_seats.text.trim());
    setState(() { _ok = null; });
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Please enter a class name, for example "Class 6 - Morning Shift".');
    if (seats == null || seats < 1) return setState(() => _error = 'Total seats must be a whole number of at least 1.');
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().api.createClass(_name.text.trim(), seats);
      final name = _name.text.trim();
      _name.clear();
      _seats.clear();
      if (mounted) setState(() => _ok = 'Created "$name" with $seats seats.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const SectionHeader('Create a class', 'School admin: each shift is its own class with its own seat limit.'),
        if (_error != null) Banner2(_error!),
        if (_ok != null) Banner2(_ok!, error: false),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Class name', hintText: 'Class 6 - Morning Shift')),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final p in _presets) ActionChip(label: Text(p, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _name.text = p)),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _seats, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total seats', hintText: '120')),
              const SizedBox(height: 18),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating…' : 'Create class')),
            ]),
          ),
        ),
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
  double _totalMs = 600000; // default hold length; grows if the server reports longer

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

  static const _titles = {
    'HELD': 'Your seat is on hold',
    'CONFIRMED': 'Admission confirmed',
    'EXPIRED': 'This application expired',
    'CANCELLED': 'Application cancelled',
  };
  static const _texts = {
    'HELD': 'Pay the admission fee before the timer runs out to keep your seat.',
    'CONFIRMED': 'Payment received. Your seat is yours. Congratulations!',
    'EXPIRED': 'The time ran out and the seat was released. You can apply again.',
    'CANCELLED': 'You cancelled this application and the seat was released.',
  };

  @override
  Widget build(BuildContext context) {
    final h = _hold;
    final status = h?.effectiveStatus(_now);
    final left = h == null ? Duration.zero : h.expiresAt.difference(_now.toUtc());
    final ms = left.isNegative ? 0 : left.inMilliseconds;
    if (status == 'HELD' && ms > _totalMs) _totalMs = ms.toDouble();
    final secs = (ms / 1000).ceil();
    final active = status == 'HELD';
    final frac = active && _totalMs > 0 ? ms / _totalMs : (status == 'CONFIRMED' ? 1.0 : 0.0);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Your application'), backgroundColor: Colors.transparent, scrolledUnderElevation: 0),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          if (_error != null) Banner2(_error!),
          if (h == null && _error == null) const Skeleton(height: 380),
          if (h != null && status != null)
            FadeSlideIn(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    CountdownRing(
                      fraction: frac,
                      urgent: active && ms <= 60000,
                      done: status == 'CONFIRMED',
                      child: status == 'CONFIRMED'
                          ? Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [kOk, Color(0xFF10B981)]), boxShadow: [BoxShadow(color: kOk.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                            )
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(active ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}' : '0:00', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
                              if (active) Text('TIME LEFT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: muted)),
                            ]),
                    ),
                    const SizedBox(height: 18),
                    StatusPill(status),
                    const SizedBox(height: 10),
                    Text(_titles[status]!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    const SizedBox(height: 6),
                    Text(_texts[status]!, textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.4)),
                    const SizedBox(height: 6),
                    Text('Application ${h.holdId}', style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 18),
                    _Stepper(status: status),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (!active || _busy) ? null : () => _act((a, s) => a.confirm(h.holdId, s), 'Payment received. Your admission is confirmed!'),
                      child: Text(_busy ? 'Please wait…' : 'Pay admission fee'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: kDanger),
                      onPressed: (!active || _busy) ? null : () => _act((a, s) => a.cancel(h.holdId, s), 'Your application was cancelled and the seat was released.'),
                      child: const Text('Cancel'),
                    ),
                  ]),
                ),
              ),
            ),
          if (_notice != null && _error == null) Padding(padding: const EdgeInsets.only(top: 14), child: Banner2(_notice!, error: false)),
        ]),
        if (status == 'CONFIRMED') const Positioned.fill(child: Confetti()),
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final pay = status == 'HELD' ? _S.on : (status == 'CONFIRMED' ? _S.good : _S.bad);
    final done = status == 'CONFIRMED' ? _S.good : _S.idle;
    return Row(children: [
      _node(context, 'Applied', _S.good, '1'),
      _line(context, true),
      _node(context, 'Payment', pay, '2'),
      _line(context, status == 'CONFIRMED'),
      _node(context, 'Confirmed', done, '3'),
    ]);
  }

  Widget _line(BuildContext context, bool active) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: AnimatedContainer(duration: const Duration(milliseconds: 500), height: 3, color: active ? kPrimary2 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
        ),
      );

  Widget _node(BuildContext context, String label, _S s, String n) {
    final color = switch (s) { _S.good => kOk, _S.on => kPrimary2, _S.bad => kDanger, _S.idle => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18) };
    final filled = s != _S.idle;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: filled ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 0, spreadRadius: 4)] : null),
        child: Center(
          child: s == _S.good
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              : s == _S.bad
                  ? const Icon(Icons.close_rounded, color: Colors.white, size: 17)
                  : Text(n, style: TextStyle(color: filled ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    ]);
  }
}

enum _S { good, on, bad, idle }
