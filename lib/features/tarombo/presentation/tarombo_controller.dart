import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horas/core/config/repository_providers.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';

/// State utama modul Tarombo (`TAR-01` .. `TAR-07`).
final class TaromboState {
  const TaromboState({
    this.profile,
    this.hasGivenConsent = false,
    this.members = const <FamilyMember>[],
    this.completenessPercent = 0,
    this.suggestions = const <PersonSummary>[],
    this.incomingClaims = const <PartuturanClaim>[],
    this.outgoingClaims = const <PartuturanClaim>[],
    this.parentNamesVisibility = FieldVisibility.onlyMe,
    this.isLoading = false,
    this.error,
  });

  final Profil? profile;
  final bool hasGivenConsent;
  final List<FamilyMember> members;
  final int completenessPercent;
  final List<PersonSummary> suggestions;
  final List<PartuturanClaim> incomingClaims;
  final List<PartuturanClaim> outgoingClaims;
  final FieldVisibility parentNamesVisibility;
  final bool isLoading;
  final AppError? error;

  TaromboState copyWith({
    Profil? profile,
    bool? hasGivenConsent,
    List<FamilyMember>? members,
    int? completenessPercent,
    List<PersonSummary>? suggestions,
    List<PartuturanClaim>? incomingClaims,
    List<PartuturanClaim>? outgoingClaims,
    FieldVisibility? parentNamesVisibility,
    bool? isLoading,
    AppError? error,
    bool clearError = false,
  }) {
    return TaromboState(
      profile: profile ?? this.profile,
      hasGivenConsent: hasGivenConsent ?? this.hasGivenConsent,
      members: members ?? this.members,
      completenessPercent: completenessPercent ?? this.completenessPercent,
      suggestions: suggestions ?? this.suggestions,
      incomingClaims: incomingClaims ?? this.incomingClaims,
      outgoingClaims: outgoingClaims ?? this.outgoingClaims,
      parentNamesVisibility:
          parentNamesVisibility ?? this.parentNamesVisibility,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller Riverpod untuk modul Tarombo (`TAR-01` .. `TAR-07`).
class TaromboController extends Notifier<TaromboState> {
  @override
  TaromboState build() {
    Future<void>.microtask(loadAll);
    return const TaromboState(isLoading: true);
  }

  Future<void> loadAll() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final taromboRepo = ref.read(taromboRepositoryProvider);
    final nearbyRepo = ref.read(nearbyRepositoryProvider);

    state = state.copyWith(isLoading: true, clearError: true);

    final profileFuture = profileRepo.getMyProfile();
    final membersFuture = taromboRepo.getMyFamilyMembers();
    final percentFuture = taromboRepo.getCompletenessPercent();
    final incomingFuture = taromboRepo.getIncomingClaims();
    final outgoingFuture = taromboRepo.getOutgoingClaims();
    final nearbyFuture = nearbyRepo.getNearbyPeople(page: 1);

    final profileRes = await profileFuture;
    final membersRes = await membersFuture;
    final percentRes = await percentFuture;
    final incomingRes = await incomingFuture;
    final outgoingRes = await outgoingFuture;
    final nearbyRes = await nearbyFuture;

    if (profileRes is Err<Profil>) {
      state = state.copyWith(isLoading: false, error: profileRes.failure);
      return;
    }
    if (membersRes is Err<List<FamilyMember>>) {
      state = state.copyWith(isLoading: false, error: membersRes.failure);
      return;
    }

    final suggestions = nearbyRes is Ok<List<PersonSummary>>
        ? nearbyRes.value
              .where(
                (p) =>
                    p.isSameMarga ||
                    (p.partuturan != null && !p.partuturan!.modeNetral),
              )
              .take(5)
              .toList(growable: false)
        : const <PersonSummary>[];

    state = state.copyWith(
      isLoading: false,
      profile: (profileRes as Ok<Profil>).value,
      hasGivenConsent: taromboRepo.hasGivenConsent,
      parentNamesVisibility: taromboRepo.parentNamesVisibility,
      members: (membersRes as Ok<List<FamilyMember>>).value,
      completenessPercent: percentRes is Ok<int> ? percentRes.value : 0,
      incomingClaims: incomingRes is Ok<List<PartuturanClaim>>
          ? incomingRes.value
          : const <PartuturanClaim>[],
      outgoingClaims: outgoingRes is Ok<List<PartuturanClaim>>
          ? outgoingRes.value
          : const <PartuturanClaim>[],
      suggestions: suggestions,
      clearError: true,
    );
  }

  Future<Result<void>> giveConsent() async {
    final res = await ref.read(taromboRepositoryProvider).giveConsent();
    if (res.isOk) {
      state = state.copyWith(hasGivenConsent: true);
    }
    return res;
  }

  Future<Result<Profil>> updateMotherMarga(String motherMarga) async {
    final res = await ref
        .read(profileRepositoryProvider)
        .updateMyProfile(motherMarga: motherMarga.trim());
    if (res.isOk) {
      await loadAll();
    }
    return res;
  }

  Future<Result<FamilyMember>> upsertMember({
    required FamilyRelationType relationType,
    required String fullName,
    required String marga,
    required UserGender gender,
    required LifeStatus lifeStatus,
    String? id,
    int? birthYear,
  }) async {
    final res = await ref
        .read(taromboRepositoryProvider)
        .upsertFamilyMember(
          id: id,
          relationType: relationType,
          fullName: fullName,
          marga: marga,
          gender: gender,
          birthYear: birthYear,
          lifeStatus: lifeStatus,
        );
    if (res.isOk) {
      await loadAll();
    }
    return res;
  }

  Future<Result<void>> deleteMember(String memberId) async {
    final res = await ref
        .read(taromboRepositoryProvider)
        .deleteFamilyMember(memberId);
    if (res.isOk) {
      await loadAll();
    }
    return res;
  }

  Future<Result<void>> deleteAllTarombo() async {
    final res = await ref.read(taromboRepositoryProvider).deleteAllMyTarombo();
    if (res.isOk) {
      final profile = state.profile;
      if (profile != null) {
        await ref
            .read(privacyRepositoryProvider)
            .updateMyPrivacySettings(
              profile.privacySettings.copyWith(tarombo: FieldVisibility.onlyMe),
            );
      }
      await loadAll();
    }
    return res;
  }

  Future<Result<void>> updatePrivacy({
    FieldVisibility? taromboVisibility,
    FieldVisibility? motherMargaVisibility,
    FieldVisibility? parentNamesVisibility,
  }) async {
    final currentProfile = state.profile;
    if (currentProfile != null &&
        (taromboVisibility != null || motherMargaVisibility != null)) {
      final updated = currentProfile.privacySettings.copyWith(
        tarombo: taromboVisibility,
        motherMarga: motherMargaVisibility,
      );
      final privRes = await ref
          .read(privacyRepositoryProvider)
          .updateMyPrivacySettings(updated);
      if (privRes is Err<PrivacySettings>) {
        return Err<void>(privRes.failure);
      }
    }
    if (parentNamesVisibility != null) {
      final parRes = await ref
          .read(taromboRepositoryProvider)
          .setParentNamesVisibility(parentNamesVisibility);
      if (parRes.isErr) return parRes;
    }
    await loadAll();
    return const Ok<void>(null);
  }

  Future<Result<PartuturanClaim>> sendClaim({
    required String targetUserId,
    required String claimedTerm,
    String? note,
  }) async {
    final res = await ref
        .read(taromboRepositoryProvider)
        .sendKinshipClaim(
          targetUserId: targetUserId,
          claimedTermForTarget: claimedTerm,
          note: note,
        );
    if (res.isOk) {
      await loadAll();
    }
    return res;
  }

  Future<Result<PartuturanClaim>> respondClaim({
    required String claimId,
    required bool accept,
  }) async {
    final res = await ref
        .read(taromboRepositoryProvider)
        .respondKinshipClaim(claimId: claimId, accept: accept);
    if (res.isOk) {
      await loadAll();
    }
    return res;
  }
}

/// Provider global untuk [TaromboController].
final taromboControllerProvider =
    NotifierProvider<TaromboController, TaromboState>(TaromboController.new);
