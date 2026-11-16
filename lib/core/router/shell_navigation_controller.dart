import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// State navigasi shell 5 tab selama sesi berjalan (PRD 4.5, Tahap 6).
final class ShellNavigationState {
  const ShellNavigationState({
    this.lastTabIndex = 0,
    this.reTapTick = 0,
  });

  final int lastTabIndex;
  final int reTapTick;

  ShellNavigationState copyWith({
    int? lastTabIndex,
    int? reTapTick,
  }) {
    return ShellNavigationState(
      lastTabIndex: lastTabIndex ?? this.lastTabIndex,
      reTapTick: reTapTick ?? this.reTapTick,
    );
  }
}

/// Controller Riverpod yang mengingat tab terakhir dan menangani ketuk ulang tab
/// untuk kembali ke halaman awal tab serta menggulung ke atas (PRD 4.5, Tahap 6).
class ShellNavigationController extends Notifier<ShellNavigationState> {
  final Map<int, ScrollController> _scrollControllers =
      <int, ScrollController>{};

  @override
  ShellNavigationState build() {
    ref.onDispose(() {
      for (final controller in _scrollControllers.values) {
        controller.dispose();
      }
      _scrollControllers.clear();
    });
    return const ShellNavigationState();
  }

  ScrollController scrollControllerForTab(int tabIndex) {
    return _scrollControllers.putIfAbsent(tabIndex, ScrollController.new);
  }

  void selectTab(int tabIndex) {
    state = state.copyWith(lastTabIndex: tabIndex);
  }

  Future<void> onReTapActiveTab(int tabIndex) async {
    state = state.copyWith(
      lastTabIndex: tabIndex,
      reTapTick: state.reTapTick + 1,
    );
    final controller = _scrollControllers[tabIndex];
    if (controller != null && controller.hasClients && controller.offset > 0) {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

/// Provider global untuk [ShellNavigationController].
final shellNavigationProvider =
    NotifierProvider<ShellNavigationController, ShellNavigationState>(
      ShellNavigationController.new,
    );
