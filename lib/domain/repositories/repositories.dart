import 'package:horas/core/errors/result.dart';
import 'package:horas/domain/models/models.dart';
import 'package:horas/domain/partuturan/partuturan_confidence.dart';

export 'debug_simulation_repository.dart';
export 'navigation_badge_repository.dart';

/// 1. Repository Autentikasi (AUT-01 .. AUT-07, AUT-R1 .. AUT-R10).
abstract interface class AuthRepository {
  String? get currentUserId;
  Future<Result<void>> sendOtp({required String phoneE164});
  Future<Result<Profil>> verifyOtp({
    required String phoneE164,
    required String otpCode,
    required String deviceName,
    required String platform,
  });
  Future<Result<Profil>> completeOnboarding({
    required String displayName,
    required UserGender gender,
    required int birthYear,
    required String marga,
    required SubEthnic subEthnic,
    required String city,
    required String subdistrict,
    String? motherMarga,
    List<String> hobbies = const <String>[],
    String? campusOrOffice,
  });
  Future<Result<List<Device>>> getActiveDevices();
  Future<Result<void>> revokeDevice(String deviceId);
  Future<Result<void>> requestAccountRecovery({
    required String oldPhoneE164,
    required String newPhoneE164,
    required String proofNote,
  });
  Future<Result<void>> logout();
}

/// 2. Repository Profil (AKN-01, AKN-02, SEK-04, AUT-R6).
abstract interface class ProfileRepository {
  Future<Result<Profil>> getMyProfile();
  Future<Result<Profil>> updateMyProfile({
    String? displayName,
    String? bio,
    String? city,
    String? subdistrict,
    String? motherMarga,
    List<String>? hobbies,
    String? campusOrOffice,
    String? websiteUrl,
    String? homeChurchName,
  });
  Future<Result<PersonSummary>> getPersonSummary(String userId);
  Future<Result<List<MargaEntry>>> getStandardMargaList({SubEthnic? subEthnic});
  Future<Result<MargaEntry>> submitCustomMarga({
    required String margaName,
    required SubEthnic subEthnic,
  });
}

/// 3. Repository Privasi (AKN-08, PRD 7.1).
abstract interface class PrivacyRepository {
  Future<Result<PrivacySettings>> getMyPrivacySettings();
  Future<Result<PrivacySettings>> updateMyPrivacySettings(
    PrivacySettings settings,
  );
}

/// 4. Repository Ikuti Satu Arah (AKN-05, AKN-06, PRD 6.3).
abstract interface class FollowRepository {
  Future<Result<Follow>> followUser(String targetUserId);
  Future<Result<void>> unfollowUser(String targetUserId);
  Future<Result<List<PersonSummary>>> getFollowers(String userId);
  Future<Result<List<PersonSummary>>> getFollowing(String userId);
}

/// 5. Repository Kenalan / Terhubung Dua Arah (AKN-12, SEK-R5, AC-05).
abstract interface class ConnectionRepository {
  Future<Result<ConnectionRequest>> sendConnectionRequest({
    required String targetUserId,
    required String introMessage,
  });
  Future<Result<void>> respondToConnectionRequest({
    required String requestId,
    required bool accept,
  });
  Future<Result<void>> removeConnection(String targetUserId);
  Future<Result<List<Connection>>> getConnections();
  Future<Result<List<ConnectionRequest>>> getIncomingRequests();
  Future<Result<List<ConnectionRequest>>> getOutgoingRequests();
}

/// 6. Repository Blokir Pengguna (AKN-11, AKN-R6, AC-11).
abstract interface class BlockRepository {
  Future<Result<Block>> blockUser(String targetUserId);
  Future<Result<void>> unblockUser(String targetUserId);
  Future<Result<List<Block>>> getBlockedUsers();
  bool isBlockedBetween(String userAId, String userBId);
}

/// 7. Repository Postingan & Feed Beranda (BER-01 .. BER-08, AKN-03, AKN-04).
abstract interface class PostRepository {
  Future<Result<List<Post>>> getFeed();
  Future<Result<Post>> getPostById(String postId);
  Future<Result<List<Post>>> getUserPosts(String userId);
  Future<Result<List<SavedPost>>> getSavedPosts();
  Future<Result<Post>> createPost({
    required String text,
    required PostVisibility visibility,
    List<String> mediaSeeds = const <String>[],
    List<int> mediaSizesBytes = const <int>[],
    List<Map<String, String>> rawExifPerMedia = const <Map<String, String>>[],
    List<String> communityIds = const <String>[],
    String? cityTag,
  });
  Future<Result<Post>> editPostText({
    required String postId,
    required String newText,
  });
  Future<Result<void>> deletePost(String postId);
  Future<Result<Post>> toggleLike(String postId);
  Future<Result<List<Like>>> getPostLikes(String postId);
  Future<Result<Post>> toggleSavePost(String postId);
}

/// 8. Repository Komentar (BER-07, BER-R5).
abstract interface class CommentRepository {
  Future<Result<List<Comment>>> getComments(String postId);
  Future<Result<Comment>> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });
  Future<Result<void>> deleteComment(String commentId);
  Future<Result<Post>> setCommentsDisabled({
    required String postId,
    required bool disabled,
  });
}

/// 9. Repository Pencarian (BER-09, BER-10, SEK-12, BER-R13).
abstract interface class SearchRepository {
  Future<Result<List<PersonSummary>>> searchPeople({
    required String query,
    String? city,
    String? marga,
  });
  Future<Result<List<Community>>> searchCommunities({
    required String query,
    String? city,
    CommunityType? type,
  });
}

/// 10. Repository Sekitar: Orang & Wilayah (SEK-01 .. SEK-03, SEK-R1 .. SEK-R3).
abstract interface class NearbyRepository {
  String get currentSelectedCity;
  void setCurrentSelectedCity(String city);
  Future<Result<List<WilayahCity>>> getAvailableCities();
  Future<Result<List<PersonSummary>>> getNearbyPeople({
    String? city,
    String? marga,
    String? hobby,
    String? campusOrOffice,
    int page = 1,
  });
}

/// 11. Repository Komunitas (SEK-05 .. SEK-08, SEK-R7 .. SEK-R11).
abstract interface class CommunityRepository {
  Future<Result<List<Community>>> getCommunities({
    String? city,
    CommunityType? type,
  });
  Future<Result<Community>> getCommunityById(String communityId);
  Future<Result<Community>> createCommunity({
    required String name,
    required CommunityType type,
    required CommunityAccessType accessType,
    required String city,
    required String description,
    String? margaName,
  });
  Future<Result<JoinRequest?>> joinCommunity(String communityId);
  Future<Result<void>> leaveCommunity(String communityId);
  Future<Result<List<Membership>>> getMembers(String communityId);
  Future<Result<List<JoinRequest>>> getPendingJoinRequests(String communityId);
  Future<Result<void>> respondJoinRequest({
    required String joinRequestId,
    required bool approve,
  });
  Future<Result<void>> setMemberRole({
    required String communityId,
    required String targetUserId,
    required CommunityRole role,
  });
  Future<Result<Announcement>> createAnnouncement({
    required String communityId,
    required String title,
    required String body,
    bool isPinned = false,
  });
  Future<Result<List<Announcement>>> getAnnouncements(String communityId);
  Future<Result<Community>> transferOwnership({
    required String communityId,
    required String newOwnerUserId,
  });
}

/// 12. Repository Sesi Main (MAN-01 .. MAN-06, MAN-09, MAN-R1 .. MAN-R9).
abstract interface class SessionRepository {
  Future<Result<List<PlaySession>>> getSessions({
    String? city,
    SportType? sportType,
    SkillLevel? skillLevel,
  });
  Future<Result<PlaySession>> getSessionById(String sessionId);
  Future<Result<PlaySession>> createSession({
    required SportType sportType,
    required String title,
    required String city,
    required DateTime startTime,
    required DateTime endTime,
    required int maxSlots,
    required SkillLevel skillLevel,
    required int feePerPersonRupiah,
    required SessionVisibility visibility,
    required SessionJoinMode joinMode,
    String? courtId,
    String? manualLocationSummary,
    String? manualLocationFullDetail,
    String notes = '',
    String? communityId,
  });
  Future<Result<PlaySession>> cancelSession(String sessionId);
  Future<Result<({Participant? participant, WaitlistEntry? waitlist})>>
  joinSession(String sessionId);
  Future<Result<void>> leaveSession(String sessionId);
  Future<Result<List<Participant>>> getParticipants(String sessionId);
  Future<Result<List<WaitlistEntry>>> getWaitlist(String sessionId);
  Future<Result<List<PaymentShare>>> getPaymentShares(String sessionId);
  Future<Result<PaymentShare>> markPaymentPaid(String paymentShareId);
  Future<Result<PaymentShare>> confirmPaymentReceived(String paymentShareId);
  Future<Result<List<PlaySession>>> getMySessionHistory();
  Future<Result<List<ReliabilityMark>>> getReliabilityMarksForHost(
    String targetUserId,
  );
}

/// 13. Repository Lapangan Olahraga (MAN-07, MAN-08, MAN-R10).
abstract interface class CourtRepository {
  Future<Result<List<Court>>> getCourts({String? city, SportType? sportType});
  Future<Result<Court>> getCourtById(String courtId);
  Future<Result<Court>> proposeCourt({
    required String name,
    required String address,
    required String city,
    required List<SportType> supportedSports,
    required String estimatedPriceText,
    required String openingHours,
  });
}

/// 14. Repository Percakapan & Pesan (PSN-01 .. PSN-06, PSN-R1 .. PSN-R9).
abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations();
  Stream<List<Message>> watchMessages(String conversationId);
  Future<Result<List<Conversation>>> getConversations();
  Future<Result<List<MessageRequest>>> getMessageRequests();
  Future<Result<Message>> sendMessage({
    required String conversationId,
    required String text,
    String? photoSeed,
    String? replyToMessageId,
  });
  Future<Result<Message>> sendFirstMessageToUser({
    required String targetUserId,
    required String text,
  });
  Future<Result<void>> respondMessageRequest({
    required String requestId,
    required MessageRequestStatus decision,
  });
  Future<Result<void>> deleteMessageForMe(String messageId);
  Future<Result<void>> deleteMessageForEveryone(String messageId);
  Future<Result<Conversation>> muteConversation({
    required String conversationId,
    required MuteDurationOption duration,
  });
}

/// 15. Repository Notifikasi (SIS-01, PRD bagian 9).
abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications();
  Future<Result<List<AppNotification>>> getNotifications();
  Future<Result<AppNotification>> push({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    required String deepLink,
  });
  Future<Result<void>> markAsRead(String notificationId);
  Future<Result<void>> markAllAsRead();
}

/// 16. Repository Laporan & Moderasi (SIS-02, SIS-03, SIS-R2 .. SIS-R4).
abstract interface class ReportRepository {
  Future<Result<Report>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String note = '',
  });
  Future<Result<List<Report>>> getMyReports();
  Future<Result<List<Strike>>> getMyStrikes();
  Future<Result<Appeal>> submitAppeal({
    required DateTime sanctionCreatedAt,
    required String reasonText,
  });
}

/// 17. Repository Verifikasi Komunitas (SIS-06, SIS-07, SIS-R6).
abstract interface class VerificationRepository {
  Future<Result<VerificationRequest>> submitCommunityVerification({
    required String communityId,
    required String evidenceDescription,
    required String contactInfo,
  });
  Future<Result<List<VerificationRequest>>> getMyVerificationRequests();
}

/// 18. Repository Tarombo & Klaim Kerabat (TAR-01 .. TAR-04, TAR-07, TAR-R1 .. TAR-R12).
abstract interface class TaromboRepository {
  bool get hasGivenConsent;
  Future<Result<void>> giveConsent();
  Future<Result<List<FamilyMember>>> getMyFamilyMembers();
  Future<Result<FamilyMember>> upsertFamilyMember({
    required FamilyRelationType relationType,
    required String fullName,
    required String marga,
    required UserGender gender,
    required LifeStatus lifeStatus,
    String? id,
    int? birthYear,
  });
  Future<Result<void>> deleteAllMyTarombo();
  Future<Result<int>> getCompletenessPercent();
  Future<Result<List<PartuturanClaim>>> getIncomingClaims();
  Future<Result<List<PartuturanClaim>>> getOutgoingClaims();
  Future<Result<PartuturanClaim>> sendKinshipClaim({
    required String targetUserId,
    required String claimedTermForTarget,
    String? note,
  });
  Future<Result<PartuturanClaim>> respondKinshipClaim({
    required String claimId,
    required bool accept,
  });
}

/// 19. Repository Partuturan & GenerationResolver (TAR-05, TAR-06, TAR-R5 .. TAR-R9).
abstract interface class PartuturanRepository {
  Future<Result<PartuturanResult>> evaluateWithUser(String targetUserId);
  Future<Result<PartuturanResult>> evaluateManual({
    required String viewerMarga,
    required UserGender viewerGender,
    required SubEthnic subEthnic,
    required String targetMarga,
    required UserGender targetGender,
    required GenerationInfo generationInfo,
    String? viewerMotherMarga,
  });
  Future<Result<PartuturanFeedback>> submitNotThisFeedback({
    required String targetMarga,
    required String? shownTerm,
    String? suggestedTerm,
    String? note,
  });
  Future<Result<Report>> reportWrongRule({
    required String ruleOrTargetId,
    required String note,
  });
}

/// 20. Repository Pusat Bantuan & Dukungan (SIS-04, SIS-05, SIS-R5).
abstract interface class SupportRepository {
  Future<Result<List<HelpArticle>>> getHelpArticles({String? query});
  Future<Result<void>> submitSupportTicket({
    required String category,
    required String message,
    String? email,
  });
}

/// 21. Repository Unduh Data & Hapus Akun (AKN-13, AKN-14, AKN-R7, AKN-R8, AC-12).
abstract interface class AccountLifecycleRepository {
  Future<Result<DataExportJob>> requestDataExport();
  Future<Result<DataExportJob?>> getLatestDataExportJob();
  Future<Result<AccountDeletion>> requestAccountDeletion();
  Future<Result<AccountDeletion?>> cancelAccountDeletion();
  Future<Result<AccountDeletion?>> getAccountDeletionStatus();
}
