# pre-commit hook: ensure encrypted with `ansible-vault`

Unconditional⋆ [`pre-commit`](https://pre-commit.com) hook to encrypt sensitive files using `ansible-vault`

**tl;dr** git hook to encrypt `terraform`'s `tfstate` files on commit using `ansible-vault`. Could be used for **other file types** as well and as a standalone script.

## Usage

0. Dependencies

- `bash`
- `yq`
- `ansible-vault`

1. Add to `.pre-commit-config.yaml` in your git repo:

``` yaml
- repo: https://github.com/thekondor/pre-commit-hook-ensure-ansiblevaulted
  rev: v0.1.4 # or other specific tag
  hooks:
    - id: ensure-ansiblevaulted
```

2. Define settings in `.ensure-ansiblevaulted.yml`:

``` yaml
# Optional. Default: enc.yaml
# The extension to be added to an encrypted file created with `enc.yaml`
encrypted-extension: vault

# Optional. Default: .with-error
# Should files to encrypted listed in `files` (see below) be checked against `.gitignore`:
# - `.with-error` fails the hook once a file to process is not added (as a pattern or as a filename) to `.gitignore`.
#   Highly recommended to prevent accidental snitching of these files to a git history.
# - `.with-warning` is similar to `.with-error` but raises a warning message instead and continues the hook's flow.
track-git-ignored: .with-warning

# Required. The value is passed "as is" to `ansible-vault`; so it could be an executable script as well.
vault-password-file: path/to/ansible-vault-password

# Required
files:
  - "*.ext"
  - "*.*another-ext"
```

Once the hook activated, all files across the repo matching either against `*.ext` or `*.*another-ext` to be encrypted using `ansible-vault` to ones `*.vault` and staged for a commit.

The files before being encrypted, firstly checked for a difference against an encrypted copy. Once they differ, they are re-encrypted using `ansible-vault edit`, otherwise skipped.

3. **Highly recommended**: add the patterns from the previous step to `.gitignore` to avoid any accidental commit to git. Files with `encrypted-extension` are subject for adding to git only.

## Rationale

### Context

While occasionally playing around with a homelab, I faced with a necessity having encrypted `terraform`'s state files before pushing them to a git. Encryption of these files are must since they can (and they do) contain sensitive data. Alternative options would be either using a remote (cloud) backend with encryption support or some other sophisticated one; for homelab that is an overkill, vendor lock or another extra dependency. Using `ansible-vault` already I want to leverage it for this use-case as well to keep everything more or less consistent way.

Hashicorp hasn't invested in a local `tfstate` encryption so far (e.g. [proposal](https://github.com/hashicorp/terraform/issues/9556); there are some more). PR for contribution seems would [not be worth the efforts](https://github.com/hashicorp/terraform/pull/28603).

### Alternative Approaches

On of the common patterns to deal with use-cases like this one, is to leverage either `git-encrypt` or local git filters. I prefer to have something more simple and more transparent (w/o being worried that the file is pushed unencrypted because of misconfiguration). That's the reason why git's builtin `pre-commit` (as a concept) hook came to rescue.

## Caveats & Current Limitations

- ⋆Unconditional - the hook is always applied independently whether files to "protect" were changed/staged or not;
- On fresh repo checkout, the files remain encrypted, so they are subject for manual decryption first;
- Files to "protect" (specified in `.ensure-ansiblevaulted.yml`):
  - have to be added manually to `.gitignore` to avoid any accidental stage (see `track-git-ignored`);
  - are limited with `find` glob-patterns;
- Each file is encrypted to a separate file-based artefact (though e.g. they all could be stored to a single `yml`-based vault).

## Disclaimer

Since this implementation is a part of my homelab, it has never been prepared for public distribution and further public support. Though the code suits the needs well, there is no guarantee that it will work for you or will work ever properly. You apply it on your own responsibility. _Bug reports, suggestions & pull requests are welcome anyway_.
