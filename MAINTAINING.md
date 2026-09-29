# Maintaining openvox-docs

Maintainer procedures for this site. For day-to-day content contribution and local
preview, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation versions

Each product's versions are listed in `_data/products.yml`, and the build derives
everything else from that file (`lib/openvox_docs/versioned_docs.rb`, run by
`_plugins/versioned_docs.rb`):

- the Jekyll collections and their front matter defaults
- the `docs/_<product>_latest` symlink, pointing at the `latest:` version
- the sidebar's nav map and the product bar's active state
- the version selector and the outdated-version banner

Nothing about versions or products is configured in `_config.yml`.

### Where pages live

Every product's pages are written once, and each version's collection directory
is assembled at build time:

```text
docs/_openvox/                  the newest version's pages, shared by every version
docs/_openvox_versions/8x/      8.x's own copies of pages that differ, and pages only 8.x has
docs/_openvox_8x/               assembled by the build: shared pages + 8.x's own pages
_data/nav/openvox.yml           one sidebar for every version
```

This works like branches in a code repository: `docs/_openvox/` is the main
branch and describes the newest version, and each older version keeps a copy of
only the pages that changed after it. So a new major needs no copying, and a fix
to a shared page reaches every version in one commit.

Other details:

- The assembled directories are gitignored, like the generated reference pages
  that `rake references:*` writes into them. Assembled files are read-only so that
  an editor warns anyone who opens one instead of its source.
- A shared page with `since: 10` in its front matter is left out of older versions.
- `page.major` is the version's major number, for `OpenVox {{ page.major }}.x` in
  shared prose and `{% if page.major >= 10 %}` for a sentence or two.
- In the nav file, `{major}` in link text is replaced for each version, and links
  to pages a version doesn't have are removed from its sidebar. A version with its
  own `_data/nav/<product>_<id>.yml` (frozen versions) uses that instead.
- `rake docs:status` lists each older version's own pages and flags any that are
  identical to the shared page again, so they can be deleted.
- `rake test:products_data` (run in CI) checks the layout: every product has a
  `docs/_<product>/` directory and a nav file, every `_versions/<id>` directory
  matches a version, and no file in an assembled directory is tracked.

### Starting a new major (preview)

Do this when the new major has a tag to build against (a prerelease is fine).
`latest` stays on the current major.

1. Add the version to the top of the product's `versions:` list in
   `_data/products.yml`. For a product with generated references, pin the
   prerelease tag:

   ```yaml
   openvox:
     latest: 9x
     versions:
       - id: 10x
         ref: "10.0.0-rc1"
       - id: 9x
         ref: "9.x"
   ```

2. Keep the current copy of the pages that differ per version (release notes,
   known issues, supported platforms, and so on) for the version that was newest
   until now:

   ```console
   bundle exec rake 'docs:preserve[openvox]'
   ```

   With no page names, this keeps every page that some older version already has
   its own copy of, which is the set that has needed a per-version copy before.
   Name pages to keep others: `rake 'docs:preserve[openvox,reporting_about.md]'`.

3. Rewrite the pages in `docs/_openvox/` for the new major. Look for version
   numbers written into shared pages and the nav:

   ```console
   git grep -nE 'OpenVox 9\b|9\.x' -- docs/_openvox _data/nav/openvox.yml
   ```

   Replace plain version labels with `{{ page.major }}` (or `{major}` in the nav)
   so they stay correct for every version. A statement that is only true for one
   major needs `docs:preserve` for that page first.

4. Generate the new series' component-version tables, for example
   `bundle exec rake references:agent_versions SERIES=10.`.

5. Build and check `/openvox/10.x/`, `/openvox/9.x/`, and `/openvox/latest/`:

   ```console
   bundle exec rake references:all INSTALLPATH=docs
   bundle exec jekyll build
   bundle exec rake test:links
   ```

### Promoting a major to latest (GA)

1. In `_data/products.yml`, set the product's `latest:` to the new version and
   switch its `ref:` from the prerelease tag to its series (`"10.x"`).
2. **No-redirect check:** the site has no redirects. A page the new major removed
   now 404s at `/openvox/latest/<page>` for existing bookmarks. `rake docs:status`
   marks those pages as "only in this version" in the older versions. Decide how
   to handle each before promoting.
3. Build and check that `/openvox/latest/` serves the new major and that older
   versions show the outdated-version banner.

To roll back, revert the `products.yml` change.

### Retiring a major (end of life)

When a version stops receiving documentation updates, snapshot it:

```console
bundle exec rake 'docs:freeze[openvox,8x]'
```

This copies every shared page the version uses into its own directory, writes its
sidebar to `_data/nav/openvox_8x.yml`, and marks it `frozen: true` in
`_data/products.yml`, so later changes to shared pages no longer reach it. Then
pin its `ref:` to its final tag so its reference pages stay reproducible.

### Adding a new product

1. Add it to `_data/products.yml` with one version.
2. Create its pages in `docs/_<product>/` and its sidebar in
   `_data/nav/<product>.yml`.
3. Add it to the product bar in `_data/navigation.yml`, and link it from
   `index.md`.

If the product will only ever have one version, set `single_version: true` and
give the version `id: latest`, as OpenVox Containers does. Otherwise use a
numbered id (`8x`) and the version picker appears once a second version is
added.
