import 'package:flutter/material.dart';

/// A panel's bounded content area, independent of the page scroll position.
class PanelScrollBody extends StatefulWidget {
  const PanelScrollBody({super.key, required this.child});

  final Widget child;

  @override
  State<PanelScrollBody> createState() => _PanelScrollBodyState();
}

class _PanelScrollBodyState extends State<PanelScrollBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    thickness: 5,
    radius: const Radius.circular(4),
    child: SingleChildScrollView(
      controller: _controller,
      primary: false,
      padding: const EdgeInsets.only(right: 12),
      child: Material(type: MaterialType.transparency, child: widget.child),
    ),
  );
}
