# Code reviews

When asked to review a PR, focus on functional blockers and security vulnerabilities introduced or worsened by the change. Investigate potential findings in the surrounding code and relevant callers before reporting them. Explain a concrete scenario that fails, why it fails, and the consequence. Do not report hypothetical problems without supporting evidence.

Also flag changes that appear unrelated to the PR's purpose, especially changes to production behavior. Check whether they are necessary for the feature before commenting. Identify the behavior change and explain why its connection to the PR is unclear. Present these as scope questions, distinct from confirmed defects.

Post each finding with `line_comment` on the most relevant changed line. Keep comments concise and actionable, and group findings with the same underlying cause.

Skip style preferences, optional refactors, requests for explanatory comments, and speculative performance improvements. Missing tests alone are not a finding. Do not describe the PR, praise the implementation, or invent findings to fill the review.

Keep the final review reply to one or two sentences without repeating inline findings. If none qualify, say that no blocking correctness, security, or scope issues were found. Mention limitations only when they materially affect that conclusion.
