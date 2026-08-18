# protocol-bench-action

[![self-test](https://github.com/nickharris808/protocol-bench-action/actions/workflows/self-test.yml/badge.svg)](https://github.com/nickharris808/protocol-bench-action/actions/workflows/self-test.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![marketplace](https://img.shields.io/badge/GitHub-Action-blue)
[![docs](https://img.shields.io/badge/docs-verification--docs-blue)](https://nickharris808.github.io/verification-docs/)

**Score a Protocol-Bench submission in CI — and fail the build if a claimed detection cannot be
proved.**

## Why this exists

A benchmark score in a README is a claim. A benchmark score enforced in CI is a guarantee. This
action runs the scorer on every push, **replays every counterexample your submission claims**, and
fails the job if the headline metric drops or a detection cannot be demonstrated.

That last part is the point. It is cheap to assert a protocol is broken and expensive to show it. A
trace that does not start at the initial state, move only along real transitions, and end in a
violating state earns no credit — so this gate cannot be passed by guessing.

## Install

Nothing to `pip install`. Reference the Action from a workflow; it installs its own dependency on
first run:

```yaml
- uses: nickharris808/protocol-bench-action@v1
  with:
    submission: submission.json
```

It is a **composite** action, so it runs `bash` on the runner and needs `python` on `PATH` (every
`ubuntu-latest` image has it) and no container. It installs
[`protocol-bench`](https://pypi.org/project/protocol-bench/) from PyPI with a `>=1.1` floor, falling
back to a `git+` install if the index is unreachable. The install is skipped entirely if
`protocol_bench` is already importable.

The version floor is load-bearing rather than cautious: `protocol-bench` 1.0.0 computed its headline
metric without consulting the replay result, so a submission that fabricated every trace scored a
perfect 1.0. Gating a build on that number would have enforced nothing.

## 30-second quickstart

Below is the **real output** of the Action's own `entrypoint.sh`, run locally with `GITHUB_OUTPUT`
and `GITHUB_STEP_SUMMARY` pointed at files. Build a submission that actually runs the checker:

```console
$ python - <<'EOF'
import json
from protocol_bench import load_tasks
from minicheck import check_safety
sub = {}
for t in load_tasks():
    r = check_safety(t.build())["properties"][t.property]
    sub[t.id] = {"violated": not r["holds"], "trace": r.get("counterexample")}
json.dump(sub, open("submission.json", "w"), default=str)
EOF
$ PB_SUBMISSION=submission.json PB_MIN_BA=0.9 PB_MIN_CEX=2 ./entrypoint.sh
$ echo $?
0
$ cat "$GITHUB_OUTPUT"
balanced-accuracy=1.0
valid-counterexamples=2
```

Now strip every trace, keeping every verdict correct — the exact submission that verdict-only
scoring would score 1.0:

```console
$ python -c "import json; d=json.load(open('submission.json')); [d[k].update(trace=None) for k in d]; json.dump(d, open('weak.json','w'))"
$ PB_SUBMISSION=weak.json PB_MIN_BA=0.9 PB_MIN_CEX=2 ./entrypoint.sh
::error::balanced accuracy 0.5 is below the required 0.9
::error::only 0 counterexamples replayed; 2 required
$ echo $?
1
$ cat "$GITHUB_OUTPUT"
balanced-accuracy=0.5
valid-counterexamples=0
```

That is the whole argument in two runs. Same verdicts, no evidence, half the score.

And a scan of nothing:

```console
$ PB_SUBMISSION=nope.json PB_MIN_BA=0.9 PB_MIN_CEX=2 ./entrypoint.sh
::error::submission file not found: nope.json
$ echo $?
3
```

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

The action writes a summary to the job page. This is the verbatim `GITHUB_STEP_SUMMARY` from the
passing run in the [quickstart](#30-second-quickstart):

> ### protocol-bench
>
> | metric | value |
> |---|---|
> | balanced accuracy | `1.0` |
> | detections claimed | `2` |
> | valid counterexamples | `2` |

## This action tests itself

The [self-test workflow](.github/workflows/self-test.yml) runs the action against **four** real cases
on every push:

| case | must |
|---|---|
| a perfect submission | pass, with both outputs populated |
| a weak submission | **fail** the gate |
| a missing file | **exit 3** |
| **a runner with nothing pre-installed** | pass — the action installs its own dependency |

That last one is there because of a defect it caught. Every other job `pip install`s
`protocol-bench` before invoking the action, which makes the entrypoint's `import protocol_bench`
succeed and skips the install line entirely — so a **broken install line stayed green**. At the time
the entrypoint ran a bare `pip install protocol-bench` against a name that was not on any index, and
the self-test could not see it. The job now asserts the package is genuinely absent before it
starts, which is the only way this line is ever actually exercised.

## Troubleshooting

**`exit 3` with `submission file not found`.** The path is resolved relative to the workspace root
(`${{ github.workspace }}`), not the workflow file. If an earlier step wrote it into a subdirectory,
give the path from the root. Exit 3 is deliberately not 0: a scorer pointed at nothing must not
report success.

**Balanced accuracy is 0.5 and my verdicts are all correct.** Then no trace replayed. Only a
*credited* detection counts, and a detection is credited only when its trace starts at the initial
state, moves along real transitions, and ends in a genuinely violating state. Run
`protocol-bench score submission.json --json` locally and read `per_task[].trace.reason`.

**`completions` is set and my `submission` is being ignored.** That is by design — `completions`
overrides `submission`. Leave `completions` empty (`""`, the default) to score a submission file.

**The gate passes on a submission I know is bad.** Check the thresholds. Both default to the vacuous
value (`min-balanced-accuracy: "0.0"`, `require-valid-counterexamples: "0"`), so an unconfigured
gate gates nothing. Set both.

**The job is slow on the first run.** It is installing `protocol-bench` and `minicheck` from git.
Pre-install them in an earlier step and the entrypoint skips its own install.

**`::error::` lines appear but the job is green.** You have `continue-on-error: true` on the step. Add
an explicit assertion on the outputs afterwards, or drop the flag.

**Outputs are empty strings.** They are only written on a run that got as far as scoring. An exit-3
run writes nothing, so branch on `steps.<id>.outcome` before reading them.

## FAQ

**"Why does a benchmark need traces? Isn't the verdict the answer?"**
Because the verdict is guessable and the trace is not. "The WPA2 four-way handshake" sits next to
"vulnerable" in every training corpus, so a model can be right about it having done no reasoning at
all. The [quickstart](#30-second-quickstart) shows the two runs side by side: identical verdicts,
`1.0` with traces and `0.5` without.

**"Fifteen tasks is a tiny benchmark."**
It is, and the README of the task set says so first. One task flipping moves balanced accuracy by
0.25. Treat per-task outcomes as the primary result and the aggregate as a summary, and always report
the task-set version alongside the number.

**"Can I use this as a security gate for my product?"**
No. The tasks are models of *published procedures*, not implementations. A passing run says a
submission scored above your threshold on those fifteen models; it says nothing about shipping code.

**"My detector found a real bug not in the task set. Does it score?"**
No — scoring is over the fixed set only. That is a property of a benchmark, not a defect. If the
finding is on one of the fifteen and the labels are wrong, that is the single most useful issue you
can open.

**"Why is a failed replay a false negative rather than an error?"**
Because a claim that cannot be demonstrated earns nothing — the same rule the rest of the portfolio
applies. Treating it as an error would let a submission convert "I could not show it" into a
non-result rather than a miss.

**"The `v1` tag — is it moving?"**
`v1` tracks the latest v1.x. Pin the full SHA if you need byte-stability, which is the normal advice
for any third-party Action.

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
