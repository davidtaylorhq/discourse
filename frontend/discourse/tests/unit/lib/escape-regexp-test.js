import { module, test } from "qunit";
import escapeRegExp from "discourse/lib/escape-regexp";

module("Unit | Lib | escape-regexp", function () {
  test("preserves plain text and empty strings", function (assert) {
    for (const input of ["", "discourse", "two words", "café 日本語"]) {
      assert.strictEqual(escapeRegExp(input), input, `preserves ${input}`);
    }
  });

  test("escapes each regular expression metacharacter", function (assert) {
    for (const character of ".*+?^${}()|[]\\") {
      assert.strictEqual(
        escapeRegExp(character),
        `\\${character}`,
        `escapes ${character}`
      );
    }
  });

  test("matches literal text containing several metacharacters", function (assert) {
    const input = "report (draft) [v2].txt";
    const pattern = new RegExp(`^${escapeRegExp(input)}$`);

    assert.true(pattern.test(input), "matches the original filename");
    assert.false(
      pattern.test("report draft v2Xtxt"),
      "does not interpret filename punctuation as regex syntax"
    );
  });

  test("preserves literal backslashes and dollar signs", function (assert) {
    const input = "C:\\reports\\$draft.txt";
    const pattern = new RegExp(`^${escapeRegExp(input)}$`);

    assert.true( pattern.test(input), "matches a path containing backslashes" );
    assert.false(
      pattern.test("C:reports$draft.txt"),
      "requires the literal backslashes"
    );
  });

  test("keeps repeated operators literal", function (assert) {
    const input = "a++b??";
    const pattern = new RegExp(`^${escapeRegExp(input)}$`);

    assert.true(pattern.test(input), "matches repeated punctuation");
    assert.false(
      pattern.test("aaab"),
      "does not treat operators as quantifiers"
    );
  });
});
