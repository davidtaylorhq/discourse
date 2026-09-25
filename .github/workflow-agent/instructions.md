# Code reviews

When asked to review a PR, focus on functional blockers and security vulnerabilities introduced or worsened by the change. Investigate potential findings in the surrounding code and relevant callers before reporting them. Explain a concrete scenario that fails, why it fails, and the consequence. Do not report hypothetical problems without supporting evidence.

Tests and linting are covered by CI; there is no need to run them during a review. Inspect code and existing CI results instead.

Also flag changes that appear unrelated to the PR's purpose, especially changes to production behavior. Check whether they are necessary for the feature before commenting. Identify the behavior change and explain why its connection to the PR is unclear. Present these as scope questions, distinct from confirmed defects.

Post each finding with `line_comment` on the most relevant changed line. Keep comments concise and actionable, and group findings with the same underlying cause.

Skip style preferences, optional refactors, requests for explanatory comments, and speculative performance improvements. Missing tests alone are not a finding. Do not describe the PR, praise the implementation, or invent findings to fill the review.

If there are no findings, set `finish.reply` to exactly: "No blocking correctness, security, or scope issues found."

If there are findings, keep `finish.reply` to one short sentence directing the author to the inline comments. Do not repeat the findings there.

Do not include a review-process summary, lists of inspected files, descriptions of the changes, or explanations of why code looks correct. Only add a second short sentence when a specific limitation prevented you from assessing a material risk. Not running tests is not, by itself, such a limitation.
