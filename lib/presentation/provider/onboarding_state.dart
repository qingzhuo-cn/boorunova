// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:boorunova/boorus/engine/site_presets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 引导流程的跨重建状态。
///
/// 语言切换会让 MaterialApp 以 locale 为 key 整树重建，从而销毁引导页的
/// 本地 State。把「当前步骤、已勾选站点」提升到 provider，重建后仍保留。
class OnboardingState {
  OnboardingState({this.step = 0, Set<BooruType>? selected})
      : selected = selected ?? <BooruType>{};

  final int step;
  final Set<BooruType> selected;

  OnboardingState copyWith({int? step, Set<BooruType>? selected}) {
    return OnboardingState(
      step: step ?? this.step,
      selected: selected ?? this.selected,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // 出厂预勾选来自 site_presets（Play 版为空集：应用装出来就是空白客户端）
    return OnboardingState(selected: kPresetOnboardingSelection);
  }

  void setStep(int step) => state = state.copyWith(step: step);

  void toggle(BooruType type, bool on) {
    final next = Set<BooruType>.of(state.selected);
    if (on) {
      next.add(type);
    } else {
      next.remove(type);
    }
    state = state.copyWith(selected: next);
  }

  void preset(Set<BooruType> selected) {
    // 必须拷贝：修复前直接持有调用方传入的 Set，调用方之后在原地增删
    // 会绕过 copyWith 悄悄改掉 provider 状态，而且不触发通知（界面不刷新）。
    state = state.copyWith(selected: Set.of(selected));
  }

  /// 引导结束时重置为初始态，避免下次（如重新引导）残留旧勾选。
  void reset() => state = OnboardingState(selected: kPresetOnboardingSelection);
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
