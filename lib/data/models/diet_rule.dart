class DietRule {
  final String verdict;
  final String? condition;
  final String? reason;

  const DietRule({
    required this.verdict,
    this.condition,
    this.reason,
  });

  factory DietRule.fromJson(Map<String, dynamic> json) {
    return DietRule(
      verdict: json['verdict'] as String,
      condition: json['condition'] as String?,
      reason: json['reason'] as String?,
    );
  }

  bool get isAllowed => verdict == 'allowed';
  bool get isForbidden => verdict == 'forbidden';
  bool get isWarning => verdict == 'warning';

  String get fullDescription {
    final StringBuffer buffer = StringBuffer();

    if (isAllowed) {
      buffer.write('Разрешено');
    } else if (isForbidden) {
      buffer.write('Запрещено');
    } else if (isWarning) {
      buffer.write('С осторожностью');
    }

    if (condition != null) {
      buffer.write(' ($condition)');
    }

    if (reason != null) {
      buffer.write(': $reason');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'DietRule($verdict, condition: $condition, reason: $reason)';
  }
}