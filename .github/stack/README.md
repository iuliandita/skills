# Stack conventions

This directory holds the shared stack conventions checker and this repository's settings for it. The format, the checks, and the vendoring steps are described in the [source README](https://github.com/iuliandita/agents/blob/develop/.github/stack/README.md).

Do not edit `canon.json` or `stack-check.py` here. Re-vendor them from [agents](https://github.com/iuliandita/agents) and regenerate `SOURCE`; the checker reports any file that differs from `SOURCE`.

Run the checker from the repository root:

```sh
python3 .github/stack/stack-check.py
```

`repo.json` is local to this repository. The weekly `stack-sync` workflow opens an issue when the canon in agents is newer than `SOURCE`.
