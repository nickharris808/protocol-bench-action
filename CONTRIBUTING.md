# Contributing

Bug reports and pull requests are welcome.

## The property this action must never violate

A score it reports must be one the scorer actually computed, over traces that actually replayed. If
you can make this action report a passing verdict for a submission whose counterexamples do not
replay, that is the most valuable bug report you can send — please open an issue with the
submission that does it.

The same rule governs the rest of the portfolio: **undetermined is not a pass**, and a claim that
cannot be demonstrated earns nothing.

## Running the tests

The action tests itself in CI. `self-test.yml` exercises the real entrypoint — including its install
step, which is deliberately *not* pre-satisfied, because a self-test that pre-installs the package
never runs the line that installs it. That mistake shipped once here and the job was green while the
action was broken.

To exercise it locally, run the workflow's steps by hand against a submission file:

```console
$ pip install "protocol-bench @ git+https://github.com/nickharris808/protocol-bench.git"
$ protocol-bench score submission.json
```

## Changing the gate

The thresholds (`min-balanced-accuracy`, `require-valid-counterexamples`) may be loosened by a user
in their own workflow, but the defaults here should stay strict. A default that passes on weak
evidence is the failure mode this whole portfolio exists to prevent.

## Licence

By contributing you agree that your work is licensed under the MIT licence, as in [LICENSE](LICENSE).
