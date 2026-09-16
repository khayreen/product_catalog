import 'package:flutter/material.dart';

/// The first-load state: nothing on screen yet, so the spinner owns it.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
