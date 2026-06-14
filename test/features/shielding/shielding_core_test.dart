import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldMatcher', () {
    test('keyword contains block matches literal text contained in title', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '猫咪睡觉合集',
        ),
        ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.keyword,
              mode: ShieldMatchMode.contains,
              pattern: '睡觉',
              scope: ShieldScope.recommendation,
            ),
          ],
        ),
      );

      expect(result.visible, isFalse);
      expect(result.blockedBy?.pattern, '睡觉');
    });

    test('keyword exact does not match partial substring in title', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '猫咪睡觉合集',
        ),
        ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.keyword,
              pattern: '睡觉',
              scope: ShieldScope.recommendation,
            ),
          ],
        ),
      );

      expect(result.visible, isTrue);
    });

    test('keyword contains is case-insensitive substring, not regex', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.keyword,
            mode: ShieldMatchMode.contains,
            pattern: 'cat.*dog',
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: 'prefix CAT.*DOG suffix',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: 'cat and dog',
          ),
          rules,
        ).visible,
        isTrue,
      );
    });

    test(
      'uid category and tag exact rules use equality instead of contains',
      () {
        final rules = ShieldRuleSet(
          rules: [
            _rule(type: ShieldRuleType.uid, pattern: '42'),
            _rule(type: ShieldRuleType.category, pattern: '游戏'),
            _rule(type: ShieldRuleType.tag, pattern: '攻略'),
          ],
        );

        expect(
          ShieldMatcher.match(
            const ShieldCandidate(scope: ShieldScope.comment, uid: '142'),
            rules,
          ).visible,
          isTrue,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              category: '单机游戏',
            ),
            rules,
          ).visible,
          isTrue,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              tags: ['攻略合集'],
            ),
            rules,
          ).visible,
          isTrue,
        );
      },
    );

    test('matches comment body, uid, category, and tag fields', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(type: ShieldRuleType.keyword, pattern: '剧透'),
          _rule(type: ShieldRuleType.uid, pattern: '42'),
          _rule(type: ShieldRuleType.category, pattern: '游戏'),
          _rule(type: ShieldRuleType.tag, pattern: '攻略'),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            body: '剧透',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(scope: ShieldScope.comment, uid: '42'),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            category: '游戏',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            tags: ['攻略'],
          ),
          rules,
        ).visible,
        isFalse,
      );
    });

    test('regex block records invalid regex without blocking other rules', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '安全内容',
        ),
        ShieldRuleSet(
          rules: [
            _rule(mode: ShieldMatchMode.regex, pattern: '['),
            _rule(pattern: '安全内容'),
          ],
        ),
      );

      expect(result.visible, isFalse);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.rule.pattern, '[');
    });

    test('token mode matches manual tokens without external services', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          tokens: ['美食', '探店'],
        ),
        ShieldRuleSet(
          rules: [
            _rule(mode: ShieldMatchMode.token, pattern: '探店'),
          ],
        ),
      );

      expect(result.visible, isFalse);
    });

    test('generic keyword rules do not match UP names', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '正常标题',
          authorName: '测试UP',
        ),
        ShieldRuleSet(
          rules: [
            _rule(type: ShieldRuleType.keyword, pattern: '测试UP'),
          ],
        ),
      );

      expect(result.visible, isTrue);
    });

    test(
      'user keyword regex blocks Chinese substring in recommendation author',
      () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            authorName: 'xx说电影',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.userKeyword,
                mode: ShieldMatchMode.regex,
                scope: ShieldScope.recommendation,
                pattern: '电影',
              ),
            ],
          ),
        );

        expect(result.visible, isFalse);
        expect(result.blockedBy?.pattern, '电影');
      },
    );

    test('user keyword token rules match split UP name tokens only', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.userKeyword,
            mode: ShieldMatchMode.token,
            pattern: '测试',
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '标题里有测试',
            authorName: '普通UP',
          ),
          rules,
        ).visible,
        isTrue,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '正常标题',
            authorName: '测试 UP',
          ),
          rules,
        ).visible,
        isFalse,
      );
    });

    test(
      'converted user keyword regex rules match UP name token boundaries',
      () {
        final rules = ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.userKeyword,
              mode: ShieldMatchMode.regex,
              pattern: shieldTokenPatternRegex('测试'),
            ),
          ],
        );

        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              authorName: '普通UP',
            ),
            rules,
          ).visible,
          isTrue,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              authorName: '测试 UP',
            ),
            rules,
          ).visible,
          isFalse,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              authorName: '测试员',
            ),
            rules,
          ).visible,
          isTrue,
        );
      },
    );

    test('reason keyword rules match only recommendation reason', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.reasonKeyword,
            mode: ShieldMatchMode.contains,
            pattern: '相似内容',
            scope: ShieldScope.recommendation,
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            reason: '因为你看过相似内容',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '标题里有相似内容',
            authorName: '相似内容UP',
          ),
          rules,
        ).visible,
        isTrue,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            body: '评论里有相似内容',
          ),
          rules,
        ).visible,
        isTrue,
      );
    });

    test('reason keyword token rules use reason tokens only', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            type: ShieldRuleType.reasonKeyword,
            mode: ShieldMatchMode.token,
            pattern: '相似内容',
            scope: ShieldScope.recommendation,
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '标题里有相似内容',
            tokens: ['标题里有相似内容'],
          ),
          rules,
        ).visible,
        isTrue,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            reason: '因为 相似内容',
            tokens: ['标题'],
          ),
          rules,
        ).visible,
        isFalse,
      );
    });

    test('allow rule wins over same type block rule', () {
      final result = ShieldMatcher.match(
        const ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '音乐现场完整版',
        ),
        ShieldRuleSet(
          rules: [
            _rule(pattern: '音乐现场完整版'),
            _rule(
              pattern: '音乐现场完整版',
              action: ShieldAction.allow,
            ),
          ],
        ),
      );

      expect(result.visible, isTrue);
      expect(result.allowedBy?.action, ShieldAction.allow);
      expect(result.blockedBy?.action, ShieldAction.block);
    });

    test(
      'disabled rules, scope mismatch, and global switch bypass matching',
      () {
        final disabled = ShieldRuleSet(
          rules: [
            _rule(pattern: '猫咪睡觉合集', enabled: false),
          ],
        );
        final scopeMismatch = ShieldRuleSet(
          rules: [
            _rule(pattern: '猫咪睡觉合集', scope: ShieldScope.comment),
          ],
        );
        final globallyDisabled = ShieldRuleSet(
          globalEnabled: false,
          rules: [_rule(pattern: '猫咪睡觉合集')],
        );
        const candidate = ShieldCandidate(
          scope: ShieldScope.recommendation,
          title: '猫咪睡觉合集',
        );

        expect(ShieldMatcher.match(candidate, disabled).visible, isTrue);
        expect(ShieldMatcher.match(candidate, scopeMismatch).visible, isTrue);
        expect(
          ShieldMatcher.match(candidate, globallyDisabled).visible,
          isTrue,
        );
      },
    );

    test('new explicit scopes match only exact same scope', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            pattern: '搜索关键词',
            scope: ShieldScope.search,
            mode: ShieldMatchMode.contains,
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.search,
            title: '搜索关键词',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.dynamic,
            title: '搜索关键词',
          ),
          rules,
        ).visible,
        isTrue,
      );
    });

    test('both scope remains recommendation and comment only', () {
      final rules = ShieldRuleSet(
        rules: [
          _rule(
            pattern: '公共关键词',
            scope: ShieldScope.both,
            mode: ShieldMatchMode.contains,
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '公共关键词',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            body: '公共关键词',
          ),
          rules,
        ).visible,
        isFalse,
      );
      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.search,
            title: '公共关键词',
          ),
          rules,
        ).visible,
        isTrue,
      );
    });

    test('global switch bypasses new scopes too', () {
      final rules = ShieldRuleSet(
        globalEnabled: false,
        rules: [
          _rule(
            pattern: '搜索关键词',
            scope: ShieldScope.search,
            mode: ShieldMatchMode.contains,
          ),
        ],
      );

      expect(
        ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.search,
            title: '搜索关键词',
          ),
          rules,
        ).visible,
        isTrue,
      );
    });

    group('contains match mode', () {
      test('keyword contains matches 猫 in 可爱小猫合集', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '可爱小猫合集',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.contains,
                pattern: '猫',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('keyword exact does not match 猫 in 可爱小猫合集', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '可爱小猫合集',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.exact,
                pattern: '猫',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('empty pattern does not match non-empty candidates', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '可爱小猫合集',
            uid: '123',
            tags: ['猫'],
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.contains,
                pattern: '',
              ),
              _rule(
                type: ShieldRuleType.uid,
                mode: ShieldMatchMode.exact,
                pattern: '',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('keyword contains matches substring in title', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '这是一个关于美食的视频',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.contains,
                pattern: '美食',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('keyword contains matches substring in body', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            body: '这个视频真的很好看',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.contains,
                pattern: '好看',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('keyword contains does not match when pattern is absent', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: '美食探店',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.keyword,
                mode: ShieldMatchMode.contains,
                pattern: '旅游',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('uid contains matches substring in uid', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            uid: '421',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.uid,
                mode: ShieldMatchMode.contains,
                pattern: '42',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('category contains matches substring', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            category: '单机游戏',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.category,
                mode: ShieldMatchMode.contains,
                pattern: '游戏',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('tag contains matches substring', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            tags: ['攻略合集'],
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.tag,
                mode: ShieldMatchMode.contains,
                pattern: '攻略',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('tag exact does not partially match', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            tags: ['攻略合集'],
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.tag,
                mode: ShieldMatchMode.exact,
                pattern: '攻略',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('userKeyword contains matches substring in author name', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            authorName: 'xx说电影',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.userKeyword,
                mode: ShieldMatchMode.contains,
                pattern: '电影',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('reasonKeyword contains matches substring in reason', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            reason: '因为你看过相似内容',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.reasonKeyword,
                mode: ShieldMatchMode.contains,
                pattern: '相似内容',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });
    });

    group('range match mode', () {
      test('duration range 60..300 matches value 180', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            durationSeconds: 180,
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.duration,
                mode: ShieldMatchMode.range,
                pattern: '60..300',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('duration range 60..300 does not match value 30', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            durationSeconds: 30,
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.duration,
                mode: ShieldMatchMode.range,
                pattern: '60..300',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('range supports open bounds and exact numeric values', () {
        final openLower = ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.duration,
              mode: ShieldMatchMode.range,
              pattern: '..300',
            ),
          ],
        );
        final openUpper = ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.duration,
              mode: ShieldMatchMode.range,
              pattern: '60..',
            ),
          ],
        );
        final exact = ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.duration,
              mode: ShieldMatchMode.range,
              pattern: '180',
            ),
          ],
        );

        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 30,
            ),
            openLower,
          ).visible,
          isFalse,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 9999,
            ),
            openUpper,
          ).visible,
          isFalse,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 180,
            ),
            exact,
          ).visible,
          isFalse,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 181,
            ),
            exact,
          ).visible,
          isTrue,
        );
      });

      test('multiple range rules on one numeric field block either edge', () {
        final rules = ShieldRuleSet(
          rules: [
            _rule(
              type: ShieldRuleType.duration,
              mode: ShieldMatchMode.range,
              pattern: '..30',
            ),
            _rule(
              type: ShieldRuleType.duration,
              mode: ShieldMatchMode.range,
              pattern: '1200..',
            ),
          ],
        );

        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 15,
            ),
            rules,
          ).visible,
          isFalse,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 300,
            ),
            rules,
          ).visible,
          isTrue,
        );
        expect(
          ShieldMatcher.match(
            const ShieldCandidate(
              scope: ShieldScope.recommendation,
              durationSeconds: 1800,
            ),
            rules,
          ).visible,
          isFalse,
        );
      });

      test('invalid range records error and does not match', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            durationSeconds: 180,
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.duration,
                mode: ShieldMatchMode.range,
                pattern: '300..60',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
        expect(result.errors, hasLength(1));
        expect(result.errors.single.rule.pattern, '300..60');
      });

      test('missing numeric field is no-match for range rule', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(scope: ShieldScope.recommendation),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.duration,
                mode: ShieldMatchMode.range,
                pattern: '60..300',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('playbackCount range matches numeric candidate field', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.recommendation,
            playbackCount: 10000,
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.playbackCount,
                mode: ShieldMatchMode.range,
                pattern: '1000..50000',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });
    });

    group('enum match mode', () {
      test('commentMemberSex enum matches normalized value', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            commentMemberSex: '女',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.commentMemberSex,
                mode: ShieldMatchMode.enumValue,
                pattern: ' 女 ',
              ),
            ],
          ),
        );
        expect(result.visible, isFalse);
      });

      test('commentMemberSex enum does not match different value', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(
            scope: ShieldScope.comment,
            commentMemberSex: '男',
          ),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.commentMemberSex,
                mode: ShieldMatchMode.enumValue,
                pattern: '女',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });

      test('missing enum field is no-match', () {
        final result = ShieldMatcher.match(
          const ShieldCandidate(scope: ShieldScope.comment),
          ShieldRuleSet(
            rules: [
              _rule(
                type: ShieldRuleType.commentMemberSex,
                mode: ShieldMatchMode.enumValue,
                pattern: '女',
              ),
            ],
          ),
        );
        expect(result.visible, isTrue);
      });
    });
  });
}

ShieldRule _rule({
  ShieldRuleType type = ShieldRuleType.keyword,
  ShieldMatchMode mode = ShieldMatchMode.exact,
  ShieldScope scope = ShieldScope.both,
  ShieldAction action = ShieldAction.block,
  required String pattern,
  bool enabled = true,
}) => ShieldRule(
  id: 'rule-$type-$mode-$scope-$action-$pattern',
  type: type,
  matchMode: mode,
  scope: scope,
  action: action,
  pattern: pattern,
  enabled: enabled,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
);
