import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:clock/clock.dart';
import 'package:horas/core/errors/app_failure.dart';
import 'package:horas/core/errors/result.dart';
import 'package:horas/data/supabase/supabase_gateway.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';
import 'package:horas/domain/partuturan/partuturan_engine.dart';
import 'package:horas/domain/policies/horas_policies.dart';
import 'package:horas/domain/policies/privacy_defaults.dart';
import 'package:horas/domain/repositories/repositories.dart';

/// 16. Implementasi Supabase untuk [ReportRepository].
final class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<Report>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String note = '',
  }) => _gw.guard(() async {
    final r = await _gw.client.rpc<Map<String, dynamic>>(
      'submit_report',
      params: <String, Object?>{
        'p_target_type': SupabaseGateway.reportTargetToSql(targetType),
        'p_target_id': targetId,
        'p_category': SupabaseGateway.reportCategoryToSql(category),
        'p_note': note,
      },
    );
    return _reportFromRow(r);
  });

  Report _reportFromRow(Map<String, dynamic> r) {
    final status = SupabaseGateway.parseReportStatus(r['status'] as String?);
    ReportOutcome? outcome;
    if (status == ReportStatus.completed) {
      outcome = r['status'] == 'dismissed'
          ? ReportOutcome.noViolation
          : ReportOutcome.actionTaken;
    }
    return Report(
      id: r['id'] as String,
      reporterId: (r['reporter_id'] as String?) ?? '',
      targetType: SupabaseGateway.parseReportTarget(
        r['target_type'] as String?,
      ),
      targetId: (r['target_id'] as String?) ?? '',
      category: SupabaseGateway.parseReportCategory(r['category'] as String?),
      note: (r['note'] as String?) ?? '',
      status: status,
      outcome: outcome,
      createdAt: SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
      resolvedAt: SupabaseGateway.parseDate(r['resolved_at']),
    );
  }

  @override
  Future<Result<List<Report>>> getMyReports() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <Report>[];
    final rows = await _gw.client
        .from('reports')
        .select()
        .eq('reporter_id', uid)
        .order('created_at', ascending: false);
    return rows.map(_reportFromRow).toList(growable: false);
  });

  @override
  Future<Result<List<Strike>>> getMyStrikes() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) return const <Strike>[];
    final rows = await _gw.client
        .from('strikes')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows
        .map(
          (r) => Strike(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            reason: (r['reason'] as String?) ?? '',
            reportId: r['report_id'] as String?,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<Appeal>> submitAppeal({
    required DateTime sanctionCreatedAt,
    required String reasonText,
  }) => _gw.guard(() async {
    final windowCheck = HorasPolicies.validateSanctionAppeal(
      sanctionCreatedAt: sanctionCreatedAt,
      now: _gw.currentTime,
    );
    if (windowCheck is Err<void>) throw windowCheck.failure;

    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }

    final strikesRes = await getMyStrikes();
    final strikes = strikesRes is Ok<List<Strike>>
        ? strikesRes.value
        : const <Strike>[];
    if (strikes.isEmpty) {
      throw const UnavailableError(
        message: 'Data pelanggaran tidak ditemukan.',
      );
    }
    final matching = strikes.reduce(
      (a, b) =>
          (a.createdAt.difference(sanctionCreatedAt).abs() <=
              b.createdAt.difference(sanctionCreatedAt).abs())
          ? a
          : b,
    );

    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'submit_appeal',
      params: <String, Object?>{
        'p_strike_id': matching.id,
        'p_reason': reasonText,
      },
    );
    final st = switch (row['status']) {
      'accepted' => AppealStatus.accepted,
      'rejected' => AppealStatus.rejected,
      _ => AppealStatus.submitted,
    };
    return Appeal(
      id: row['id'] as String,
      userId: uid,
      sanctionCreatedAt: matching.createdAt,
      reasonText: (row['reason'] as String?) ?? reasonText,
      status: st,
      createdAt:
          SupabaseGateway.parseDate(row['created_at']) ?? _gw.currentTime,
    );
  });
}

/// 17. Implementasi Supabase untuk [VerificationRepository].
final class SupabaseVerificationRepository implements VerificationRepository {
  SupabaseVerificationRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<VerificationRequest>> submitCommunityVerification({
    required String communityId,
    required String evidenceDescription,
    required String contactInfo,
  }) => _gw.guard(() async {
    final commRow = await _gw.client
        .from('communities')
        .select('name')
        .eq('id', communityId)
        .single();
    final commName = (commRow['name'] as String?) ?? '';

    final r = await _gw.client.rpc<Map<String, dynamic>>(
      'submit_verification_request',
      params: <String, Object?>{
        'p_community_id': communityId,
        'p_organization_name': commName,
        'p_document_path': contactInfo,
        'p_notes': evidenceDescription,
      },
    );
    return _verFromRow(r, commName);
  });

  VerificationRequest _verFromRow(Map<String, dynamic> r, String commName) {
    final st = switch (r['status']) {
      'approved' => VerificationStatus.approved,
      'rejected' => VerificationStatus.rejected,
      _ => VerificationStatus.submitted,
    };
    return VerificationRequest(
      id: r['id'] as String,
      requesterId: (r['requester_id'] as String?) ?? '',
      communityId: r['community_id'] as String,
      communityName: (r['organization_name'] as String?)?.isNotEmpty == true
          ? r['organization_name'] as String
          : commName,
      evidenceDescription: (r['notes'] as String?) ?? '',
      contactInfo: (r['document_path'] as String?) ?? '',
      status: st,
      rejectionReason: r['review_note'] as String?,
      createdAt: SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
    );
  }

  @override
  Future<Result<List<VerificationRequest>>> getMyVerificationRequests() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <VerificationRequest>[];
        final rows = await _gw.client
            .from('verification_requests')
            .select()
            .eq('requester_id', uid)
            .order('created_at', ascending: false);
        return rows.map((r) => _verFromRow(r, '')).toList(growable: false);
      });
}

/// 18. Implementasi Supabase untuk [TaromboRepository].
final class SupabaseTaromboRepository implements TaromboRepository {
  SupabaseTaromboRepository(this._gw);

  final SupabaseGateway _gw;
  static const String _kConsentLocal = 'horas_sb_tarombo_consent_v1';
  static const String _kParentVisLocal = 'horas_sb_tarombo_parent_vis_v1';

  @override
  bool get hasGivenConsent => _gw.prefs?.getBool(_kConsentLocal) ?? false;

  @override
  FieldVisibility get parentNamesVisibility {
    final raw = _gw.prefs?.getString(_kParentVisLocal);
    return SupabaseGateway.parseFieldVisibility(raw, FieldVisibility.onlyMe);
  }

  @override
  Future<Result<void>> giveConsent() => _gw.guard(() async {
    await _gw.prefs?.setBool(_kConsentLocal, true);
    final uid = _gw.currentUserId;
    if (uid != null) {
      await _gw.client
          .from('profiles')
          .update(<String, Object?>{
            'tarombo_consent_at': _gw.currentTime.toIso8601String(),
          })
          .eq('id', uid);
    }
  });

  @override
  Future<Result<void>> setParentNamesVisibility(FieldVisibility visibility) =>
      _gw.guard(() async {
        final sql = SupabaseGateway.fieldVisibilityToSql(visibility);
        await _gw.prefs?.setString(_kParentVisLocal, sql);
        final uid = _gw.currentUserId;
        if (uid != null) {
          await _gw.client
              .from('profiles')
              .update(<String, Object?>{'tarombo_parent_names_vis': sql})
              .eq('id', uid);
        }
      });

  FamilyMember _memberFromRow(Map<String, dynamic> r) => FamilyMember(
    id: r['id'] as String,
    ownerUserId: r['owner_id'] as String,
    relationType: SupabaseGateway.parseFamilyRelation(r['relation'] as String?),
    fullName: (r['name'] as String?) ?? '',
    marga: (r['marga'] as String?) ?? '',
    gender: SupabaseGateway.parseGender(r['gender'] as String?),
    lifeStatus: SupabaseGateway.parseLifeStatus(r['life_status'] as String?),
    birthYear: r['birth_year'] as int?,
    linkedUserId: r['linked_user_id'] as String?,
  );

  @override
  Future<Result<List<FamilyMember>>> getMyFamilyMembers() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <FamilyMember>[];
        final rows = await _gw.client
            .from('family_members')
            .select()
            .eq('owner_id', uid)
            .order('created_at', ascending: true);
        return rows.map(_memberFromRow).toList(growable: false);
      });

  @override
  Future<Result<FamilyMember>> upsertFamilyMember({
    required FamilyRelationType relationType,
    required String fullName,
    required String marga,
    required UserGender gender,
    required LifeStatus lifeStatus,
    String? id,
    int? birthYear,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final payload = <String, Object?>{
      if (id != null && id.isNotEmpty) 'id': id,
      'owner_id': uid,
      'relation': SupabaseGateway.familyRelationToSql(relationType),
      'name': fullName.trim(),
      'marga': marga.trim(),
      'gender': gender.jsonCode,
      'birth_year': birthYear,
      'life_status': lifeStatus == LifeStatus.deceased ? 'almarhum' : 'hidup',
    };
    final row = await _gw.client
        .from('family_members')
        .upsert(payload)
        .select()
        .single();
    return _memberFromRow(row);
  });

  @override
  Future<Result<void>> deleteFamilyMember(String memberId) =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return;
        await _gw.client
            .from('family_members')
            .delete()
            .eq('id', memberId)
            .eq('owner_id', uid);
      });

  @override
  Future<Result<void>> deleteAllMyTarombo() => _gw.guard(() async {
    await _gw.client.rpc<Object?>('delete_all_my_tarombo');
    await _gw.prefs?.setBool(_kConsentLocal, false);
  });

  @override
  Future<Result<List<PersonSummary>>> findPotentialLinksForMember(
    String memberId,
  ) => _gw.guard(() async {
    final row = await _gw.client
        .from('family_members')
        .select('name, marga')
        .eq('id', memberId)
        .single();
    final res = await _gw.client.rpc<List<Object?>>(
      'search_people',
      params: <String, Object?>{
        'p_query': (row['name'] as String?) ?? '',
        'p_marga': (row['marga'] as String?) ?? '',
      },
    );
    return res
        .whereType<Map<Object?, Object?>>()
        .map(
          (m) => PersonSummary.fromJson(
            m.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<int>> getCompletenessPercent() => _gw.guard(() async {
    final prof = _gw.currentSessionProfile;
    final membersRes = await getMyFamilyMembers();
    final members = membersRes is Ok<List<FamilyMember>>
        ? membersRes.value
        : const <FamilyMember>[];
    var score = 0;
    if ((prof?.motherMarga ?? '').trim().isNotEmpty) score += 20;
    if (members.any((m) => m.relationType == FamilyRelationType.father)) {
      score += 20;
    }
    if (members.any((m) => m.relationType == FamilyRelationType.mother)) {
      score += 20;
    }
    if (members.any(
      (m) => m.relationType == FamilyRelationType.paternalGrandfather,
    )) {
      score += 20;
    }
    if (members.any(
      (m) => m.relationType == FamilyRelationType.maternalGrandfather,
    )) {
      score += 20;
    }
    return score;
  });

  Future<List<PartuturanClaim>> _hydrateClaims(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{};
    for (final r in rows) {
      ids.add(r['proposer_id'] as String);
      ids.add(r['target_id'] as String);
    }
    final people = await _gw.getBatchPersonSummaries(ids);
    return rows
        .map((r) {
          final st = switch (r['status']) {
            'confirmed' => PartuturanClaimStatus.accepted,
            'rejected' => PartuturanClaimStatus.rejected,
            _ => PartuturanClaimStatus.pending,
          };
          return PartuturanClaim(
            id: r['id'] as String,
            sender: people[r['proposer_id'] as String]!,
            receiver: people[r['target_id'] as String]!,
            claimedTermForReceiver: (r['claimed_istilah'] as String?) ?? '',
            note: r['lineage_note'] as String?,
            status: st,
            createdAt:
                SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            respondedAt: SupabaseGateway.parseDate(
              r['confirmed_at'] ?? r['rejected_at'],
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Result<List<PartuturanClaim>>> getIncomingClaims() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <PartuturanClaim>[];
        final rows = await _gw.client
            .from('partuturan_claims')
            .select()
            .eq('target_id', uid)
            .order('created_at', ascending: false);
        return _hydrateClaims(rows);
      });

  @override
  Future<Result<List<PartuturanClaim>>> getOutgoingClaims() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return const <PartuturanClaim>[];
        final rows = await _gw.client
            .from('partuturan_claims')
            .select()
            .eq('proposer_id', uid)
            .order('created_at', ascending: false);
        return _hydrateClaims(rows);
      });

  @override
  Future<Result<PartuturanClaim>> sendKinshipClaim({
    required String targetUserId,
    required String claimedTermForTarget,
    String? note,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'propose_partuturan_claim',
      params: <String, Object?>{
        'p_target_id': targetUserId,
        'p_claimed_istilah': claimedTermForTarget,
        'p_generation_delta': null,
        'p_lineage_note': note ?? '',
      },
    );
    final hydrated = await _hydrateClaims(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });

  @override
  Future<Result<PartuturanClaim>> respondKinshipClaim({
    required String claimId,
    required bool accept,
  }) => _gw.guard(() async {
    final row = await _gw.client.rpc<Map<String, dynamic>>(
      'respond_partuturan_claim',
      params: <String, Object?>{'p_claim_id': claimId, 'p_confirm': accept},
    );
    final hydrated = await _hydrateClaims(<Map<String, dynamic>>[row]);
    return hydrated.first;
  });
}

/// 19. Implementasi Supabase untuk [PartuturanRepository] (Tugas 7).
final class SupabasePartuturanRepository implements PartuturanRepository {
  SupabasePartuturanRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<PartuturanResult>> evaluateWithUser(
    String targetUserId,
  ) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final engine = await _gw.partuturanService.createEngine();
    final genInfo = await _gw.partuturanService.resolveGenerationDelta(
      viewerId: uid,
      targetId: targetUserId,
    );
    final summaryRes = await _gw.getBatchPersonSummaries(<String>[
      targetUserId,
    ]);
    final target = summaryRes[targetUserId]!;
    final viewer = _gw.currentSessionProfile;
    if (viewer == null) {
      throw const PermissionDeniedError(
        message: 'Profil belum dimuat.',
        permissionName: 'auth',
      );
    }

    final claimRow = await _gw.client
        .from('partuturan_claims')
        .select('claimed_istilah')
        .eq('status', 'confirmed')
        .or(
          'and(proposer_id.eq.$uid,target_id.eq.$targetUserId),and(proposer_id.eq.$targetUserId,target_id.eq.$uid)',
        )
        .maybeSingle();

    return engine.evaluate(
      PartuturanEvaluationInput(
        viewerMarga: viewer.marga,
        viewerGender: viewer.gender,
        viewerMotherMarga: viewer.motherMarga,
        subEthnic: viewer.subEthnic,
        targetMarga: target.marga,
        targetGender: target.gender,
        targetMotherMarga: target.visibleMotherMarga,
        generationInfo: genInfo,
        confirmedKinshipTerm: claimRow?['claimed_istilah'] as String?,
      ),
    );
  });

  @override
  Future<Result<PartuturanResult>> evaluateBetweenUsers({
    required String userAId,
    required String userBId,
  }) => _gw.guard(() async {
    final people = await _gw.getBatchPersonSummaries(<String>[
      userAId,
      userBId,
    ]);
    final a = people[userAId]!;
    final b = people[userBId]!;
    final engine = await _gw.partuturanService.createEngine();
    final genInfo = await _gw.partuturanService.resolveGenerationDelta(
      viewerId: userAId,
      targetId: userBId,
    );
    return engine.evaluate(
      PartuturanEvaluationInput(
        viewerMarga: a.marga,
        viewerGender: a.gender,
        viewerMotherMarga: a.visibleMotherMarga,
        subEthnic: a.subEthnic,
        targetMarga: b.marga,
        targetGender: b.gender,
        targetMotherMarga: b.visibleMotherMarga,
        generationInfo: genInfo,
      ),
    );
  });

  @override
  Future<Result<PartuturanResult>> evaluateManual({
    required String viewerMarga,
    required UserGender viewerGender,
    required SubEthnic subEthnic,
    required String targetMarga,
    required UserGender targetGender,
    required GenerationInfo generationInfo,
    String? viewerMotherMarga,
    String? targetMotherMarga,
    String? specificBranch,
  }) => _gw.guard(() async {
    final engine = await _gw.partuturanService.createEngine(
      refreshFromRemote: false,
    );
    return engine.evaluate(
      PartuturanEvaluationInput(
        viewerMarga: viewerMarga,
        viewerGender: viewerGender,
        viewerMotherMarga: viewerMotherMarga,
        subEthnic: subEthnic,
        targetMarga: targetMarga,
        targetGender: targetGender,
        targetMotherMarga: targetMotherMarga,
        specificBranch: specificBranch,
        generationInfo: generationInfo,
      ),
    );
  });

  @override
  Future<Result<PartuturanFeedback>> submitNotThisFeedback({
    required String targetMarga,
    required String? shownTerm,
    String? suggestedTerm,
    String? note,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final viewerMarga = _gw.currentSessionProfile?.marga ?? '';
    final row = await _gw.client
        .from('partuturan_feedback')
        .insert(<String, Object?>{
          'user_id': uid,
          'viewer_marga': viewerMarga,
          'target_marga': targetMarga,
          'shown_term': shownTerm,
          'suggested_istilah': suggestedTerm ?? '',
          'is_accurate': false,
          'notes': note ?? '',
        })
        .select()
        .single();
    return PartuturanFeedback(
      id: row['id'] as String,
      userId: uid,
      viewerMarga: viewerMarga,
      targetMarga: targetMarga,
      shownTerm: shownTerm,
      suggestedTerm: suggestedTerm,
      note: note,
      ruleVersion: (row['rule_version'] as String?) ?? '0.1.0-draft',
      createdAt:
          SupabaseGateway.parseDate(row['created_at']) ?? _gw.currentTime,
    );
  });

  @override
  Future<Result<Report>> reportWrongRule({
    required String ruleOrTargetId,
    required String note,
  }) => SupabaseReportRepository(_gw).submitReport(
    targetType: ReportTargetType.user,
    targetId: ruleOrTargetId,
    category: ReportCategory.wrongPartuturanRule,
    note: note,
  );
}

/// 20. Implementasi Supabase untuk [SupportRepository].
final class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  Future<Result<List<HelpArticle>>> getHelpArticles({
    String? query,
  }) => _gw.guard(() async {
    var q = _gw.client.from('help_articles').select();
    final clean = (query ?? '').trim();
    if (clean.isNotEmpty) {
      q = q.or(
        'question.ilike.%$clean%,answer.ilike.%$clean%,category.ilike.%$clean%',
      );
    }
    final rows = await q.order('sort_order', ascending: true);
    return rows
        .map(
          (r) => HelpArticle(
            id: r['id'] as String,
            category: (r['category'] as String?) ?? '',
            question: (r['question'] as String?) ?? '',
            answer: (r['answer'] as String?) ?? '',
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<void>> submitSupportTicket({
    required String category,
    required String message,
    String? email,
    String? attachmentSeed,
  }) => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    await _gw.client.from('support_tickets').insert(<String, Object?>{
      'user_id': uid,
      'category': category,
      'subject': category,
      'message': message.trim(),
      'contact_email': email?.trim(),
      'attachment_path': attachmentSeed,
    });
  });

  @override
  Future<Result<List<SupportTicket>>> getMySupportTickets() => _gw.guard(
    () async {
      final uid = _gw.currentUserId;
      if (uid == null) return const <SupportTicket>[];
      final rows = await _gw.client
          .from('support_tickets')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return rows
          .map(
            (r) => SupportTicket(
              id: r['id'] as String,
              userId: uid,
              category: (r['category'] as String?) ?? '',
              message: (r['message'] as String?) ?? '',
              email: r['contact_email'] as String?,
              attachmentSeed: r['attachment_path'] as String?,
              createdAt:
                  SupabaseGateway.parseDate(r['created_at']) ?? _gw.currentTime,
            ),
          )
          .toList(growable: false);
    },
  );
}

/// 21. Implementasi Supabase untuk [AccountLifecycleRepository].
final class SupabaseAccountLifecycleRepository
    implements AccountLifecycleRepository {
  SupabaseAccountLifecycleRepository(this._gw);

  final SupabaseGateway _gw;

  DataExportJob _exportFromRow(Map<String, dynamic> r) {
    final st = switch (r['status']) {
      'ready' => DataExportStatus.ready,
      'expired' => DataExportStatus.expired,
      _ => DataExportStatus.processing,
    };
    final reqAt =
        SupabaseGateway.parseDate(r['requested_at']) ?? _gw.currentTime;
    return DataExportJob(
      id: r['id'] as String,
      userId: (r['user_id'] as String?) ?? '',
      status: st,
      downloadUrl: r['download_path'] as String?,
      requestedAt: reqAt,
      expiresAt:
          SupabaseGateway.parseDate(r['expires_at']) ??
          reqAt.add(const Duration(days: 7)),
    );
  }

  AccountDeletion _deletionFromRow(Map<String, dynamic> r) => AccountDeletion(
    id: r['id'] as String,
    userId: (r['user_id'] as String?) ?? '',
    requestedAt:
        SupabaseGateway.parseDate(r['requested_at']) ?? _gw.currentTime,
    scheduledPermanentDeletionAt:
        SupabaseGateway.parseDate(r['scheduled_permanent_deletion_at']) ??
        _gw.currentTime.add(const Duration(days: 30)),
    isCancelled: (r['is_cancelled'] as bool?) ?? false,
    isPermanentlyDeleted: (r['is_permanently_deleted'] as bool?) ?? false,
  );

  @override
  Future<Result<DataExportJob>> requestDataExport({String? otpCode}) =>
      _gw.guard(() async {
        final row = await _gw.client.rpc<Map<String, dynamic>>(
          'request_data_export',
        );
        return _exportFromRow(row);
      });

  @override
  Future<Result<List<int>>> buildExportZipBytes() => _gw.guard(() async {
    final uid = _gw.currentUserId;
    if (uid == null) {
      throw const PermissionDeniedError(
        message: 'Login diperlukan.',
        permissionName: 'auth',
      );
    }
    final prof = await _gw.client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    final posts = await _gw.client.from('posts').select().eq('author_id', uid);
    final family = await _gw.client
        .from('family_members')
        .select()
        .eq('owner_id', uid);

    final archive = Archive();
    void addJson(String name, Object? data) {
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson('profile.json', prof);
    addJson('posts.json', posts);
    addJson('tarombo_family.json', family);
    return ZipEncoder().encode(archive);
  });

  @override
  Future<Result<DataExportJob?>> getLatestDataExportJob() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return null;
        final row = await _gw.client
            .from('data_export_jobs')
            .select()
            .eq('user_id', uid)
            .order('requested_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : _exportFromRow(row);
      });

  @override
  Future<Result<AccountDeletion>> requestAccountDeletion({String? otpCode}) =>
      _gw.guard(() async {
        final row = await _gw.client.rpc<Map<String, dynamic>>(
          'request_account_deletion',
          params: <String, Object?>{'p_reason': 'Permintaan pengguna'},
        );
        return _deletionFromRow(row);
      });

  @override
  Future<Result<AccountDeletion?>> cancelAccountDeletion() =>
      _gw.guard(() async {
        final row = await _gw.client.rpc<Map<String, dynamic>>(
          'cancel_account_deletion',
        );
        return _deletionFromRow(row);
      });

  @override
  Future<Result<AccountDeletion?>> getAccountDeletionStatus() =>
      _gw.guard(() async {
        final uid = _gw.currentUserId;
        if (uid == null) return null;
        final row = await _gw.client
            .from('account_deletions')
            .select()
            .eq('user_id', uid)
            .maybeSingle();
        return row == null ? null : _deletionFromRow(row);
      });
}

/// 22. Stub [DebugSimulationRepository] untuk mode Supabase nyata (non-mock).
final class SupabaseDebugSimulationRepository
    implements DebugSimulationRepository {
  SupabaseDebugSimulationRepository(this._gw);

  final SupabaseGateway _gw;

  @override
  DebugSimulationState get state => DebugSimulationState(
    currentUserId: _gw.currentUserId ?? '',
    currentNow: clock.now(),
  );

  @override
  List<DebugMockUserOption> get availableMockUsers =>
      const <DebugMockUserOption>[];

  @override
  void advanceClock(Duration delta) {}

  @override
  void clearAccountSanctions() {}

  @override
  List<Report> getReportsForDebug() => const <Report>[];

  @override
  List<VerificationRequest> getVerificationRequestsForDebug() =>
      const <VerificationRequest>[];

  @override
  void resetClock() {}

  @override
  Future<void> resetAllData() async {}

  @override
  void setChatAutoReplyEnabled(bool value) {}

  @override
  void setEmptyState(bool value) {}

  @override
  void setOffline(bool value) {}

  @override
  void setServerError(bool value) {}

  @override
  void setSlowNetwork(bool value) {}

  @override
  void simulateAddStrike({String reason = 'Pelanggaran pedoman'}) {}

  @override
  void simulateSuspendCurrentAccount() {}

  @override
  Future<void> switchMockUser(String userId) async {}

  @override
  void updateReportStatusForDebug({
    required String reportId,
    required ReportStatus status,
    ReportOutcome? outcome,
  }) {}

  @override
  void updateVerificationStatusForDebug({
    required String requestId,
    required VerificationStatus status,
    String? rejectionReason,
  }) {}
}
