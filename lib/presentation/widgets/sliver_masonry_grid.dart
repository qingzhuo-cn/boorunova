import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class AppSliverMasonryGrid extends StatelessWidget {
  const AppSliverMasonryGrid({
    super.key,
    required this.crossAxisCount,
    required this.childCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
  });

  final int crossAxisCount;
  final int childCount;
  final IndexedWidgetBuilder itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childCount: childCount,
      itemBuilder: itemBuilder,
    );
  }
}
