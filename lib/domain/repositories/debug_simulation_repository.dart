import 'package:horas/domain/models/sub_ethnic.dart';

/// Ringkasan akun tiruan untuk pemilih pengguna di Panel Debug (Prompt 2 Bagian D).
typedef DebugMockUserOption = ({
  String id,
  String displayName,
  String marga,
  SubEthnic subEthnic,
  String city,
});

/// State simulasi Panel Debug non-prod.
final class DebugSimulationState {
  const DebugSimulationState({
    required this.currentUserId,
    required this.currentNow,
    this.isOffline = false,
    this.isServerError = false,
    this.isEmptyState = false,
    this.isSlowNetwork = false,
    this.isChatAutoReplyEnabled = true,
    this.timeOffset = Duration.zero,
    this.activeStrikesCount = 0,
    this.isAccountSuspended = false,
  });

  final String currentUserId;
  final DateTime currentNow;
  final bool isOffline;
  final bool isServerError;
  final bool isEmptyState;
  final bool isSlowNetwork;
  final bool isChatAutoReplyEnabled;
  final Duration timeOffset;
  final int activeStrikesCount;
  final bool isAccountSuspended;
}

/// Antarmuka abstrak pengendali simulasi Panel Debug (hanya aktif pada build non-prod).
abstract interface class DebugSimulationRepository {
  DebugSimulationState get state;
  List<DebugMockUserOption> get availableMockUsers;

  void setOffline(bool value);
  void setServerError(bool value);
  void setEmptyState(bool value);
  void setSlowNetwork(bool value);
  void setChatAutoReplyEnabled(bool value);

  Future<void> switchMockUser(String userId);
  void advanceClock(Duration delta);
  void resetClock();

  void simulateAddStrike({String reason});
  void simulateSuspendCurrentAccount();
  void clearAccountSanctions();
  Future<void> resetAllData();
}
