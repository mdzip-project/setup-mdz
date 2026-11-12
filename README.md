# MDZip GitHub Action (setup-mdz)

Installs [`mdz`](https://github.com/mdzip-project/mdzip-cli), the command-line tool for MDZip (`.mdz`) files, and adds it to `PATH`. Later steps can then validate, create, inspect and diff `.mdz` archives: a document's Markdown and its images in one file. See [mdzip.org](https://mdzip.org) for the format.

```yaml
- uses: mdzip-project/setup-mdz@v1
  with:
    version: 2.1.0
- run: mdz validate docs/guide.mdz
```

Works on Linux, macOS and Windows runners, x64 and Arm64. Each download is checked against the SHA-256 digest GitHub records for the release file.

## Inputs

| Input | Default | What it does |
|---|---|---|
| `version` | `latest` | The `mdz` version to install, such as `2.1.0`. Pin one, so a new release can't change your builds without you knowing. |
| `token` | `github.token` | Used to look up the release on the GitHub API, which limits anonymous requests. |

## Outputs

| Output | Example |
|---|---|
| `version` | `2.1.0` |
| `path` | The folder holding `mdz`, already on `PATH` |

## Examples

### Check every `.mdz` in pull requests

```yaml
name: Check .mdz files
on: pull_request
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: mdzip-project/setup-mdz@v1
        with:
          version: 2.1.0
      - name: Validate
        shell: bash
        run: |
          shopt -s globstar nullglob
          for f in **/*.mdz; do mdz validate "$f"; done
```

### Package a docs folder on each release

Keep the Markdown and images as plain files in the repo, and build the `.mdz` when you release:

```yaml
name: Package docs
on:
  release:
    types: [published]
permissions:
  contents: write
jobs:
  package:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: mdzip-project/setup-mdz@v1
        with:
          version: 2.1.0
      - run: mdz create docs "docs-${{ github.event.release.tag_name }}.mdz" --title "Project docs"
      - run: mdz validate "docs-${{ github.event.release.tag_name }}.mdz"
      - run: gh release upload "${{ github.event.release.tag_name }}" docs-*.mdz
        env:
          GH_TOKEN: ${{ github.token }}
```

### Show what changed inside an `.mdz`

`mdz textconv` prints an archive as text, so you can diff two versions in a job, for example in a pull request:

```yaml
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: mdzip-project/setup-mdz@v1
        with:
          version: 2.1.0
      - name: Diff guide.mdz against the base branch
        run: |
          git config diff.mdz.textconv "mdz textconv"
          echo "*.mdz diff=mdz" >> .git/info/attributes
          git diff "origin/${{ github.base_ref }}" -- docs/guide.mdz
```

See [`mdz textconv`](https://github.com/mdzip-project/mdzip-cli#mdz-textconv-archive) for setting this up locally too.

## License

Apache 2.0. See [LICENSE](LICENSE).
