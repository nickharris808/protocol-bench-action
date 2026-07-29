# protocol-bench-action

[![self-test](https://img.shields.io/badge/self--test-passing-brightgreen)](https://github.com/nickharris808/protocol-bench-action/actions/workflows/self-test.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![marketplace](https://img.shields.io/badge/GitHub-Action-blue)

**Score a Protocol-Bench submission in CI — and fail the build if a claimed detection cannot be
proved.**

## Why this exists

A benchmark score in a README is a claim. A benchmark score enforced in CI is a guarantee. This
action runs the scorer on every push, **replays every counterexample your submission claims**, and
fails the job if the headline metric drops or a detection cannot be demonstrated.

That last part is the point. It is cheap to assert a protocol is broken and expensive to show it. A
trace that does not start at the initial state, move only along real transitions, and end in a
violating state earns no credit — so this gate cannot be passed by guessing.

## Usage

```yaml
- uses: nickharris808/protocol-bench-action@v1
  with:
    submission: submission.json
    min-balanced-accuracy: "0.9"
    require-valid-counterexamples: "2"
```

Scoring raw model completions instead of a submission:

```yaml
- uses: nickharris808/protocol-bench-action@v1
  with:
    completions: completions.json          # {task_id: "model reply text"}
    min-balanced-accuracy: "0.6"
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `submission` | `submission.json` | Task id → `{violated, trace}` |
| `completions` | *(empty)* | Raw model replies; **overrides** `submission` |
| `min-balanced-accuracy` | `0.0` | Fail the job below this |
| `require-valid-counterexamples` | `0` | Fail unless at least this many traces replay |

## Outputs

| Output | Description |
|---|---|
| `balanced-accuracy` | The headline metric |
| `valid-counterexamples` | Detections whose trace actually replayed |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Thresholds met |
| `1` | Thresholds not met |
| `3` | **Misconfigured** — no input file. A scan of nothing never reports success. |

That third one matters: a CI gate that silently passes when pointed at a missing file is worse than
no gate at all.

## Example output

The action writes a summary to the job page:

> ### protocol-bench
>
> | metric | value |
> |---|---|
> | balanced accuracy | `1.0` |
> | detections claimed | `2` |
> | valid counterexamples | `2` |

## This action tests itself

The [self-test workflow](.github/workflows/self-test.yml) runs the action against three real cases on
every push: a perfect submission that must pass with both outputs populated, a weak submission that
**must fail** the gate, and a missing file that **must exit 3**. If the gate ever stops gating, the
build goes red.

## Honest scope

**What a passing run establishes.** That the submission you gave it scored at or above your declared
thresholds on the fifteen tasks in `protocol-bench`, and that every counterexample it claimed was
replayed against the model it claims to break — starting at the initial state, moving only along real
transitions, ending in a genuinely violating state.

**What it does not establish.**

- Nothing about protocols beyond the fifteen in the task set. Fifteen tasks with two violated is a
  small sample: a single task flipping moves balanced accuracy by 0.25, which is why the score should
  always be reported with the task set version rather than on its own.
- Nothing about any implementation. The tasks are models of published *procedures*; a model
  abstracts, and an abstraction can hide a real defect.
- Nothing about a submission's reasoning. A replaying trace shows the counterexample is real, not
  that it was derived rather than recalled — that is what the `spec` mode and
  [`specforge`](https://github.com/nickharris808/specforge) exist to probe.
- Nothing when a threshold is loosened. `min-balanced-accuracy: "0"` makes the gate vacuous; the
  defaults are strict on purpose.

**A failed replay is scored as no detection, never as an error.** A claim that cannot be
demonstrated earns nothing, which is the same rule the rest of the portfolio applies.

## The portfolio

| | |
|---|---|
| [`minicheck`](https://github.com/nickharris808/minicheck) | The engine: an explicit-state model checker with a CLI. Shortest counterexamples, no required dependencies. |
| [`protocol-bench`](https://github.com/nickharris808/protocol-bench) | Published IEEE 802.11 / 3GPP procedures with ground-truth verdicts. A claimed detection must **replay**. |
| [`specforge`](https://github.com/nickharris808/specforge) | A benchmark that cannot be memorised — ground truth is *computed* by the checker, not written down. |
| [`minicheck-mcp`](https://github.com/nickharris808/minicheck-mcp) | The checker as an **MCP server**, so an agent can verify a state machine instead of guessing. |
| [`minicheck-action`](https://github.com/nickharris808/minicheck-action) | Model-check every spec in a repo, in CI. Diagrams in the PR, SARIF in the Security tab. |
| [`protocol-bench-action`](https://github.com/nickharris808/protocol-bench-action) ← *you are here* | Score a submission in CI and fail the build if a claimed detection cannot be proved by replay. |
| [`failclosed`](https://github.com/nickharris808/failclosed) | Default-deny ASGI middleware: a gated endpoint succeeds only on an affirmative verdict. |
| [`polyfrac`](https://github.com/nickharris808/polyfrac) | Exact polynomial and rational-function arithmetic over ℚ with Sturm real-root counting. Zero deps. |
| [**the docs site**](https://nickharris808.github.io/verification-docs/) | The front door: why a verdict you cannot check is not a verdict, and how these compose. |

One idea runs through all of them: **a verdict you cannot check is not a verdict** — and its
corollary, which governs every surface here: *undetermined is not a pass.*

**Try it in the browser** · [model-check a state machine](https://huggingface.co/spaces/nickh007/protocol-bench-demo) · [the specforge leaderboard](https://huggingface.co/spaces/nickh007/specforge-leaderboard)

**Ground-truth data** · [protocol-bench](https://huggingface.co/datasets/nickh007/protocol-bench) · [specforge](https://huggingface.co/datasets/nickh007/specforge)

### The commercial offering

These are the engine. What is **not** open source is what makes it useful at scale: the maintained
hazard-property corpora, composition analysis that finds hazards existing only when two components
are combined, the trust-model sensitivity sweep, and the evidence trail that makes a verdict auditable
after the fact. The tools above are MIT and stay that way.

## Documentation

Full documentation, including the concepts guide and an honest comparison against TLA+, SPIN, Alloy
and CBMC, is at **[https://nickharris808.github.io/verification-docs/](https://nickharris808.github.io/verification-docs/)**.

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). A counterexample
that this tool gets wrong is the single most useful thing you can send.

## Citing

Citation metadata is in [CITATION.cff](CITATION.cff); GitHub renders a *Cite this repository* button
from it.

## Licence

MIT. See [LICENSE](LICENSE).
