import 'package:flutter/material.dart';

import '../api/app_update.dart';

/// The Settings-reached update flow: a plain confirm dialog ("Update
/// available, want it?"), then — only if the user says yes — a second
/// dialog showing download progress. Deliberately NOT the fullscreen
/// [UpdateScreen] used at cold launch: that one is a blocking pre-Home
/// screen shown before the dashboard even exists, so it earns being a full
/// screen; this one is reached from a settings row that's already a popup,
/// where a fullscreen page would be the only non-popup thing in the whole
/// Settings flow.
Future<void> showUpdatePopup(
  BuildContext context, {
  required AppUpdateInfo info,
  required String currentVersion,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Koti $currentVersion → ${info.version}'),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(child: Text(info.notes)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now')),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update Now')),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _UpdateProgressDialog(info: info),
  );
}

class _UpdateProgressDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateProgressDialog({required this.info});

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  // Primed to 0 (not null) since the download starts immediately in
  // initState — the alternative, setting it via setState there, runs before
  // the first frame and Flutter flags that as unsafe.
  double? _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await downloadAndInstallApk(
        widget.info.apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'Update failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      title: const Text('Updating Koti'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (downloading) ...[
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            const SizedBox(height: 12),
            Text('Downloading… ${((_progress ?? 0) * 100).toStringAsFixed(0)}%'),
          ] else
            const Text(
                'Handed off to Android\'s installer — look for the install prompt.'),
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(onPressed: _run, child: const Text('Retry')),
        TextButton(
          onPressed: downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
