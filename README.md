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

## The portfolio

Five small tools built around one idea: **a verdict you cannot check is not a verdict.**

| | |
|---|---|
| [`protocol-bench`](https://github.com/nickharris808/protocol-bench) | The benchmark this action scores — 15 published IEEE 802.11 / 3GPP procedures |
| [`minicheck`](https://github.com/nickharris808/minicheck) | The model checker behind it, ~560 lines, no required deps |
| [`minicheck-mcp`](https://github.com/nickharris808/minicheck-mcp) | The same checker as an MCP server, for AI agents |
| [`polyfrac`](https://github.com/nickharris808/polyfrac) | Exact rational arithmetic with Sturm real-root counting |
| [`failclosed`](https://github.com/nickharris808/failclosed) | Default-deny ASGI middleware for verdict-gated endpoints |

Try it in your browser: **[live demo](https://huggingface.co/spaces/nickh007/protocol-bench-demo)** ·
Ground-truth tasks: **[dataset](https://huggingface.co/datasets/nickh007/protocol-bench)**

### The commercial offering

This action scores a public benchmark. The maintained hazard-property corpora, composition analysis
that finds hazards existing only when two components are combined, the trust-model sensitivity sweep,
and the evidence trail that makes a verdict auditable after the fact are the commercial offering. The
tools above are MIT and stay that way.

## Licence

MIT. See [`LICENSE`](LICENSE).
