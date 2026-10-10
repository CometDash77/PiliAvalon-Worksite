/// Provider routing contract (issues #31/#38).
///
/// The provider is always an explicit user choice: the shape of an API key is
/// only ever a UI hint and never routes a credential.
enum JevProvider {
  typeSafe(
    id: 'typesafe',
    label: 'TypeSafe',
    endpoint: 'https://api.typesafe.ai/v1/systemone',
    model: 'jev-latest',
  ),
  openRouter(
    id: 'openrouter',
    label: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/alpha/decisions',
    model: 'typesafe/jev-latest',
  );

  const JevProvider({
    required this.id,
    required this.label,
    required this.endpoint,
    required this.model,
  });

  /// Stable id persisted in settings.
  final String id;

  /// User-facing provider name.
  final String label;

  /// Typed-decision endpoint of this provider.
  final String endpoint;

  /// Pinned model identifier.
  ///
  /// `typesafe/jev-latest` is the OpenRouter-side model id (issue #101: the
  /// previously pinned `typesafe/jev-1.13` does not exist upstream and turned
  /// every OpenRouter validation into a rejected request) while the TypeSafe
  /// direct call uses the documented `jev-latest` alias (issue #31/#59, gap
  /// G-01). A model id echoed back by the provider is observed only and is never
  /// persisted.
  final String model;

  static JevProvider? tryFromId(String? id) {
    for (final provider in values) {
      if (provider.id == id) return provider;
    }
    return null;
  }
}

/// Recommendation surfaces covered by Jev (issues #29/#43).
///
/// Every surface carries its own switch; a surface is only screened when the
/// master switch is on as well.
enum JevSurface {
  homeWeb(id: 'home_web', label: '首页推荐（Web）'),
  homeApp(id: 'home_app', label: '首页推荐（App）'),
  related(id: 'related', label: '相关推荐'),
  hot(id: 'hot', label: '热门'),
  ranking(id: 'ranking', label: '排行榜'),
  live(id: 'live', label: '直播推荐'),
  pgc(id: 'pgc', label: '番剧/影视推荐'),
  music(id: 'music', label: '音乐推荐列表');

  const JevSurface({required this.id, required this.label});

  final String id;
  final String label;

  static JevSurface? tryFromId(String? id) {
    for (final surface in values) {
      if (surface.id == id) return surface;
    }
    return null;
  }
}

/// The single product-defined question (issue #34).
///
/// Users cannot write prompts; every surface and every candidate is judged with
/// this exact question.
abstract final class JevQuestion {
  static const String text = '这条推荐的核心内容，是否与用户明确不喜欢的主题存在足够强的语义匹配，以至于应在展示前屏蔽？';
}

/// Conservative limits of the local Jev stage.
///
/// The decision tickets never fixed the timeout, concurrency, retry, or batch
/// numbers (gaps G-09/G-10) and the provider context limits were never collected
/// (gap G-15). The values below are local defaults on the conservative side of
/// every stated rule: they are not provider guarantees, and they must be
/// re-validated against locally labelled data before the hide threshold is
/// trusted.
abstract final class JevLimits {
  /// Low end of the 3-5 batch hypothesis in issue #36.
  static const int batchSize = 3;

  static const Duration requestTimeout = Duration(seconds: 8);

  /// Batches are serialised: at most one Jev request is in flight.
  static const int maxConcurrentRequests = 1;

  /// No retries: a failed evaluation fails open right away.
  static const int maxAttempts = 1;

  /// Maximum themes kept in the local explicit negative profile (issue #33).
  static const int maxProfileThemes = 20;

  /// A theme with no new feedback for six months is dropped (issue #33).
  static const Duration themeTtl = Duration(days: 183);

  /// Hide gate for a Noul answer; anything below stays visible (issue #36).
  static const double hideNoulThreshold = 0.95;

  /// When a provider reports a confidence, a low one keeps the candidate.
  static const double minReportedConfidence = 0.9;

  /// Upper bound for the serialised preference state (gap G-03).
  static const int maxStateBytes = 2048;

  /// A stored preference theme is capped to this many runes (gap G-05).
  static const int maxThemeChars = 16;

  /// Approximate counts saturate here (gap G-05): the profile keeps a magnitude,
  /// not an exact tally.
  static const int maxThemeCount = 999;
}

/// Request/response shape used by this implementation.
///
/// The decision tickets fixed the envelope (`{state, model, questions}`) but not
/// the individual field names (gaps G-03/G-04). Local decision: keep that
/// envelope, key every question by a per-batch ordinal that carries no card
/// identity, and describe each question with the atomic question text.
abstract final class JevRequest {
  static const String stateField = 'state';
  static const String modelField = 'model';
  static const String questionsField = 'questions';
  static const String questionIdField = 'id';
  static const String questionTextField = 'question';

  /// Per-candidate context carried inside its keyed question. Title is
  /// mandatory; snippet and tags ride along only when the card already has
  /// them. Never an id, a link, an uploader, or any long metadata (issue #34).
  static const String candidateField = 'candidate';
  static const String candidateTitleField = 'title';
  static const String candidateSnippetField = 'snippet';
  static const String candidateTagsField = 'tags';

  /// Ordinal question id, e.g. `candidate_1`. Never derived from a video id,
  /// a title, or any other card identity.
  static String candidateKey(int index) => 'candidate_${index + 1}';

  static Map<String, Object?> question(
    String id, {
    Map<String, Object?>? candidate,
  }) => <String, Object?>{
    questionIdField: id,
    questionTextField: JevQuestion.text,
    candidateField: ?candidate,
  };

  static Map<String, Object?> body({
    required String model,
    required Map<String, Object?> state,
    required List<Map<String, Object?>> questions,
  }) => <String, Object?>{
    stateField: state,
    modelField: model,
    questionsField: questions,
  };
}

/// Answer-side field names, parsed leniently: a Noul answer carries 'noul',
/// a Choice/Score answer additionally carries 'confidence' (issue #31, gap
/// G-04). Anything unreadable fails open in the evaluator.
abstract final class JevResponse {
  static const String answersField = 'answers';
  static const String noulField = 'noul';
  static const String confidenceField = 'confidence';
}
