import 'package:flutter/material.dart';

enum BuildState { idle, running, success, failed, cancelled }

@immutable
class BuildStatus {
  final BuildState state;
  final double progress;
  final String currentStep;

  const BuildStatus({
    this.state = BuildState.idle,
    this.progress = 0,
    this.currentStep = '',
  });

  BuildStatus copyWith({
    BuildState? state,
    double? progress,
    String? currentStep,
  }) {
    return BuildStatus(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}
