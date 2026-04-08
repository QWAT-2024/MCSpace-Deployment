import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double width;
  final double height;

  const CustomLoadingIndicator({
    super.key,
    this.width = 150,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/images/loading.json',
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
