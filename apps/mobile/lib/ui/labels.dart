import '../domain/enums.dart';
import '../l10n/gen/app_localizations.dart';

/// Traduction des valeurs du contrat en libellés courts.
extension Labels on AppLocalizations {
  String referralStatus(String wire) => switch (ReferralStatus.fromWire(wire)) {
        ReferralStatus.proposed => referralProposed,
        ReferralStatus.accepted => referralAccepted,
        ReferralStatus.arrived => referralArrived,
        ReferralStatus.transferred => referralTransferred,
        ReferralStatus.notCompleted => referralNotCompleted,
        null => wire,
      };

  String ancStatus(String wire) => switch (AncVisitStatus.fromWire(wire)) {
        AncVisitStatus.planned => ancPlanned,
        AncVisitStatus.done => ancDone,
        AncVisitStatus.missed => ancMissed,
        AncVisitStatus.cancelled => ancCancelled,
      };

  String pregnancyStatus(String wire) => switch (wire) {
        'active' => pregnancyActive,
        'delivered' => pregnancyDelivered,
        'ended' => pregnancyEnded,
        'transferred' => pregnancyTransferred,
        _ => wire,
      };

  String alertStatus(String wire) => switch (wire) {
        'open' => alertOpen,
        'acknowledged' => alertAcknowledged,
        'resolved' => alertResolved,
        'escalated' => alertEscalated,
        'cancelled' => alertCancelled,
        _ => wire,
      };

  String consentScope(String wire) => switch (ConsentScope.fromWire(wire)) {
        ConsentScope.reny => scopeReny,
        ConsentScope.tanora => scopeTanora,
        ConsentScope.reminders => scopeReminders,
        ConsentScope.voiceProcessing => scopeVoice,
        null => wire,
      };

  String consentMethodLabel(String wire) =>
      wire == ConsentMethod.written.wire ? methodWritten : methodOral;

  String channel(PreferredChannel c) => switch (c) {
        PreferredChannel.sms => channelSms,
        PreferredChannel.ivr => channelIvr,
        PreferredChannel.acVisit => channelAcVisit,
        PreferredChannel.none => channelNone,
      };

  String confirmedByLabel(DatesConfirmedBy c) => switch (c) {
        DatesConfirmedBy.acDeclared => confirmedAc,
        DatesConfirmedBy.healthWorker => confirmedHealthWorker,
        DatesConfirmedBy.ultrasound => confirmedUltrasound,
      };

  String entity(String wire) => switch (SyncEntity.fromWire(wire)) {
        SyncEntity.beneficiary => entityBeneficiary,
        SyncEntity.beneficiaryIdentity => entityIdentity,
        SyncEntity.consent => entityConsent,
        SyncEntity.pregnancy => entityPregnancy,
        SyncEntity.ancVisit => entityAncVisit,
        SyncEntity.referral => entityReferral,
        SyncEntity.alert => entityAlert,
        SyncEntity.site => entitySite,
        null => wire,
      };

  String? syncError(String? code) => switch (code) {
        null => null,
        'offline' => syncErrorOffline,
        'session_expired' => syncErrorSession,
        _ => syncErrorServer,
      };

  /// Orientation lisible pour une action du moteur de règles (jamais un
  /// diagnostic). Énumération fermée du contrat (section 8 bis).
  String action(String code) => switch (code) {
        'refer_csb' => actionReferCsb,
        'transfer_counselor' => actionReferAdvisor,
        'refer_community_agent' => actionReferCommunityAgent,
        'refer_reference_facility' => actionReferFacility,
        _ => actionOther(code),
      };

  String siteKind(String wire) => switch (SiteKind.fromWire(wire)) {
        SiteKind.csb => siteKindCsb,
        SiteKind.referenceFacility => siteKindReference,
        SiteKind.communityZone => siteKindCommunity,
        null => wire,
      };
}
