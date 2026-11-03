enum DanmakuShieldRuleError { empty, tooLong }

abstract final class DanmakuShieldRule {
  static const maxLength = 64;

  static DanmakuShieldRuleError? validate(String rule) {
    if (rule.isEmpty) return DanmakuShieldRuleError.empty;
    if (rule.length > maxLength) return DanmakuShieldRuleError.tooLong;
    return null;
  }
}
