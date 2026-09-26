enum RecordingMode { off, manual, continuous, detection }

const animalLabels = {
  'bird',
  'cat',
  'dog',
  'horse',
  'sheep',
  'cow',
  'elephant',
  'bear',
  'zebra',
  'giraffe',
};

class CameraRule {
  const CameraRule({
    this.mode = RecordingMode.off,
    this.people = false,
    this.animals = false,
  });
  final RecordingMode mode;
  final bool people;
  final bool animals;
  bool get detects => people || animals;
  bool get active => mode != RecordingMode.off || detects;

  CameraRule copyWith({RecordingMode? mode, bool? people, bool? animals}) =>
      CameraRule(
        mode: mode ?? this.mode,
        people: people ?? this.people,
        animals: animals ?? this.animals,
      );
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'people': people,
    'animals': animals,
  };
  factory CameraRule.fromJson(Map<String, dynamic> json) => CameraRule(
    mode: RecordingMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => RecordingMode.off,
    ),
    people: json['people'] == true,
    animals: json['animals'] == true,
  );
  List<String> matches(List<dynamic> results) => results
      .whereType<Map>()
      .where(
        (r) =>
            (r['score'] as num? ?? 0) >= .55 &&
            (people && r['label'] == 'person' ||
                animals && animalLabels.contains(r['label'])),
      )
      .map((r) => r['label'] as String)
      .toSet()
      .toList();
}

class NvrSettings {
  const NvrSettings({
    this.enabled = false,
    this.quotaGb = 2,
    this.rules = const {},
  });
  final bool enabled;
  final int quotaGb;
  final Map<String, CameraRule> rules;
  CameraRule rule(String id) => rules[id] ?? const CameraRule();
  NvrSettings copyWith({
    bool? enabled,
    int? quotaGb,
    Map<String, CameraRule>? rules,
  }) => NvrSettings(
    enabled: enabled ?? this.enabled,
    quotaGb: quotaGb ?? this.quotaGb,
    rules: rules ?? this.rules,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'quotaGb': quotaGb,
    'rules': rules.map((id, rule) => MapEntry(id, rule.toJson())),
  };
  factory NvrSettings.fromJson(Map<String, dynamic> json) => NvrSettings(
    enabled: json['enabled'] == true,
    quotaGb: [1, 2, 4, 8, 16].contains(json['quotaGb'])
        ? json['quotaGb'] as int
        : 2,
    rules: (json['rules'] as Map? ?? {}).map<String, CameraRule>(
      (id, rule) => MapEntry(
        id as String,
        CameraRule.fromJson(Map<String, dynamic>.from(rule as Map)),
      ),
    ),
  );
}
