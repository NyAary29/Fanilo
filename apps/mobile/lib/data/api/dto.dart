/// Objets de transfert du contrat d'API (sections 1, 6 et 8).
library;

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime? refreshExpiresAt;

  factory TokenPair.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 0;
    final refreshIn = (json['refresh_expires_in'] as num?)?.toInt();
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessExpiresAt: t.add(Duration(seconds: expiresIn)),
      refreshExpiresAt:
          refreshIn == null ? null : t.add(Duration(seconds: refreshIn)),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.login,
    required this.role,
    required this.siteId,
    required this.isActive,
  });

  final String id;
  final String login;
  final String role;
  final String? siteId;
  final bool isActive;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        login: json['login'] as String,
        role: json['role'] as String,
        siteId: json['site_id'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'login': login,
        'role': role,
        'site_id': siteId,
        'is_active': isActive,
      };
}

// ---------------------------------------------------------------- sync

class PushChange {
  const PushChange({
    required this.changeId,
    required this.entity,
    required this.op,
    required this.id,
    required this.baseVersion,
    required this.data,
  });

  final String changeId;
  final String entity;
  final String op;
  final String id;
  final int? baseVersion;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'change_id': changeId,
        'entity': entity,
        'op': op,
        'id': id,
        'base_version': baseVersion,
        'data': data,
      };
}

enum PushStatus { applied, conflict, rejected, unknown }

class PushResult {
  const PushResult({
    required this.changeId,
    required this.status,
    this.serverVersion,
    this.serverData,
    this.error,
  });

  final String changeId;
  final PushStatus status;
  final int? serverVersion;
  final Map<String, dynamic>? serverData;
  final String? error;

  /// `error` vaut `{code, message}` (contrat, section 8) : on affiche le
  /// message, suivi du code entre parenthèses.
  static String? _errorText(Object? err) {
    if (err == null) return null;
    if (err is Map) {
      final message = err['message']?.toString();
      final code = err['code']?.toString();
      if (message != null && message.isNotEmpty) {
        return code == null ? message : '$message ($code)';
      }
      if (code != null) return code;
    }
    return err.toString();
  }

  factory PushResult.fromJson(Map<String, dynamic> json) {
    final s = json['status'];
    final status = switch (s) {
      'applied' => PushStatus.applied,
      'conflict' => PushStatus.conflict,
      'rejected' => PushStatus.rejected,
      _ => PushStatus.unknown,
    };
    final err = json['error'];
    return PushResult(
      changeId: json['change_id'] as String,
      status: status,
      serverVersion: (json['server_version'] as num?)?.toInt(),
      serverData: (json['server_data'] as Map?)?.cast<String, dynamic>(),
      error: _errorText(err),
    );
  }
}

class PullChange {
  const PullChange({
    required this.entity,
    required this.id,
    required this.version,
    required this.deletedAt,
    required this.data,
  });

  final String entity;
  final String id;
  final int version;
  final String? deletedAt;
  final Map<String, dynamic>? data;

  factory PullChange.fromJson(Map<String, dynamic> json) => PullChange(
        entity: json['entity'] as String,
        id: json['id'] as String,
        version: (json['version'] as num).toInt(),
        deletedAt: json['deleted_at'] as String?,
        data: (json['data'] as Map?)?.cast<String, dynamic>(),
      );
}

class PullResponse {
  const PullResponse({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PullChange> changes;
  final String? nextCursor;
  final bool hasMore;

  factory PullResponse.fromJson(Map<String, dynamic> json) => PullResponse(
        changes: ((json['changes'] as List?) ?? const [])
            .map((e) => PullChange.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        nextCursor: json['next_cursor'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------- ask

class AskContent {
  const AskContent({
    required this.code,
    required this.title,
    required this.body,
    required this.status,
  });
  final String code;
  final String title;
  final String body;
  final String status;

  factory AskContent.fromJson(Map<String, dynamic> json) => AskContent(
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        status: json['status'] as String? ?? 'demo',
      );
}

class AskResponse {
  const AskResponse({
    required this.interactionId,
    required this.outcome,
    required this.actions,
    required this.severity,
    required this.content,
    required this.alertId,
    required this.isDemo,
    required this.disclaimer,
  });

  final String interactionId;

  /// `answer`, `danger_sign` ou `fallback`.
  final String outcome;
  final List<String> actions;
  final String? severity;
  final AskContent? content;
  final String? alertId;
  final bool isDemo;
  final String disclaimer;

  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
        interactionId: json['interaction_id'] as String? ?? '',
        outcome: json['outcome'] as String? ?? 'fallback',
        actions: ((json['actions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        severity: json['severity'] as String?,
        content: json['content'] is Map
            ? AskContent.fromJson((json['content'] as Map).cast())
            : null,
        alertId: json['alert_id'] as String?,
        isDemo: json['is_demo'] as bool? ?? true,
        disclaimer: json['disclaimer'] as String? ??
            'FANILO ne remplace pas un professionnel de santé.',
      );
}
