import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Orange strip shown while the device radio has no connection. Checks the
/// current state on open (the change stream alone misses "already offline").
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, this.text = 'Нет сети'});

  final String text;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  List<ConnectivityResult>? _results;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _results = results);
    });
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _results = results);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final offline =
        results != null && !results.any((r) => r != ConnectivityResult.none);
    if (!offline) return const SizedBox.shrink();
    return Material(
      color: Colors.deepOrange,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
