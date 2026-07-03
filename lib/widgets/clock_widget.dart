import 'dart:async';
import 'package:flutter/material.dart';

/// Local device clock, updated once a minute. Formatted by hand (no `intl`
/// dependency, per CLAUDE.md's footprint budget) since we only need a
/// simple `H:MM AM/PM` readout.
class ClockWidget extends StatefulWidget {
  final TextStyle? style;
  const ClockWidget({super.key, this.style});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(DateTime t) {
    final hour24 = t.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(_now),
      style: widget.style ??
          const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
    );
  }
}
