import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an AI request failed, as returned by the ai-layout function.
enum AiError { badRequest, rateLimited, unavailable, badOutput, timeout }

class AiFailure implements Exception {
  const AiFailure(this.error);
  final AiError error;
}

/// Calls the ai-layout Edge Function. Returns the raw candidates; nothing
/// from the model is trusted until the app's validator has checked it.
abstract class AiService {
  /// [feedback] lists earlier layouts and what the app's checks found wrong.
  Future<List<Object?>> suggest({
    required String goal,
    required Map<String, Object?> input,
    List<Map<String, Object?>> feedback = const [],
  });
}

class SupabaseAiService implements AiService {
  SupabaseAiService(this._client);

  final SupabaseClient _client;

  /// The function gives up after 20 s per call; the app waits 25 s in all.
  static const clientTimeout = Duration(seconds: 25);

  static AiError _code(Object? code) => switch (code) {
    'bad_request' => AiError.badRequest,
    'rate_limited' => AiError.rateLimited,
    'ai_bad_output' => AiError.badOutput,
    'ai_timeout' => AiError.timeout,
    _ => AiError.unavailable,
  };

  @override
  Future<List<Object?>> suggest({
    required String goal,
    required Map<String, Object?> input,
    List<Map<String, Object?>> feedback = const [],
  }) async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
    try {
      final res = await _client.functions
          .invoke(
            'ai-layout',
            body: {
              'goal': goal,
              'input': input,
              if (feedback.isNotEmpty) 'feedback': feedback,
            },
          )
          .timeout(clientTimeout);
      final data = res.data;
      if (data is Map<String, Object?> && data['candidates'] is List<Object?>) {
        return data['candidates']! as List<Object?>;
      }
      throw const AiFailure(AiError.badOutput);
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map<String, Object?> ? details['error'] : null;
      throw AiFailure(
        _code(error is Map<String, Object?> ? error['code'] : null),
      );
    } on TimeoutException {
      throw const AiFailure(AiError.timeout);
    }
  }
}
