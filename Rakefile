# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'pathname'
require 'fileutils'
require 'yaml'
require 'rake/clean'

require 'rubocop/rake_task'

require_relative 'lib/openvox_docs/versioned_docs'

RuboCop::RakeTask.new do |task|
  task.plugins << 'rubocop-rake'
end

clobber_dirs = [
  # ceated by references rake sub tasks
  'references_output',
  'vendor/openbolt',
  'vendor/openfact',
  'vendor/openvox',
  '.yardoc',
  # created by running jekyll
  '_site',
  '.jekyll-cache',
]

clobber_dirs.each do |dir|
  CLOBBER.include(dir)
end

desc 'List the available groups of references. Run `rake references:<GROUP>` to build.'
task :references do
  puts 'The following references are available:'
  puts 'bundle exec rake references:openvox [VERSION=<GIT TAG OR COMMIT> COLLECTION=<DIR> INSTALLPATH=<RELATIVE OR ABSOLUTE PATH>]'
  puts 'bundle exec rake references:openfact [VERSION=<GIT TAG OR COMMIT> COLLECTION=<DIR> INSTALLPATH=<RELATIVE OR ABSOLUTE PATH>]'
  puts 'bundle exec rake references:openbolt [VERSION=<GIT TAG OR COMMIT> COLLECTION=<DIR> INSTALLPATH=<RELATIVE OR ABSOLUTE PATH>]'
  puts '  VERSION can be omitted, uses latest non-prerelease tag; a series like 8.x uses the latest non-prerelease tag in that series; anything else builds that exact ref (e.g. a 9.x prerelease)'
  puts '  COLLECTION can be omitted, defaults to the collection of the product\'s latest version (e.g. _openvox_8x); set it to build another version (e.g. _openvox_9x)'
  puts '  INSTALLPATH can be omitted, defaults to references_output/'
  puts 'bundle exec rake references:all [INSTALLPATH=<RELATIVE OR ABSOLUTE PATH>]'
  puts '  Builds every pinned product/version from _data/products.yml into its collection'
end

namespace :references do
  # The collection behind `/<product>/latest/`. The `_<product>_latest`
  # symlinks are created by the Jekyll build, so they may not exist yet.
  latest_collection = lambda do |product_id|
    ENV.fetch('COLLECTION') do
      OpenvoxDocs::VersionedDocs.latest_version(OpenvoxDocs::VersionedDocs.load_products(Dir.pwd)[product_id])['collection']
    end
  end

  task openvox: 'references:check' do
    require 'puppet_references'
    PuppetReferences.build_puppet_references(ENV.fetch('VERSION', nil), collection: latest_collection.call('openvox'))
  end

  task openfact: 'references:check' do
    require 'puppet_references'
    PuppetReferences.build_facter_references(ENV.fetch('VERSION', nil), collection: latest_collection.call('openfact'))
  end

  task openbolt: 'references:check' do
    require 'puppet_references'
    PuppetReferences.build_openbolt_references(ENV.fetch('VERSION', nil), collection: latest_collection.call('openbolt'))
  end

  desc 'Build every pinned product/version from _data/products.yml into its collection'
  task :all do
    versions = OpenvoxDocs::VersionedDocs.load_products(Dir.pwd)
    installpath = ENV.fetch('INSTALLPATH', nil)

    # Each (product, version) builds in its own subprocess. A fresh process avoids
    # cross-version contamination from load-time output constants and process-level
    # caches (e.g. the Strings JSON cache), and re-resolves bundler cleanly for the
    # vendored repo it checks out. Only products with a `references` task generate
    # reference pages; authored-only products are skipped.
    versions.each do |product_id, product|
      task_name = product['references']
      next unless task_name

      product.fetch('versions', []).each do |version|
        ref = version['ref']
        collection = version['collection']
        unless ref && collection
          warn "references:all: skipping #{product_id} #{version['id']} (missing ref or collection)"
          next
        end

        cmd = ['bundle', 'exec', 'rake', task_name, "VERSION=#{ref}", "COLLECTION=#{collection}"]
        cmd << "INSTALLPATH=#{installpath}" if installpath
        puts "references:all: #{cmd.join(' ')}"
        Bundler.with_unbundled_env { sh(*cmd) }
      end
    end
  end

  # The agent/server/openvoxdb tables are per-OpenVox-series: each writes into a
  # file named for the collection's nav_key (e.g. openvox_8x), so the component-
  # versions page can render its own series via `site.data.<table>[page.nav]` and
  # a future 9.x collection gets its own data file without colliding. The nav_key
  # is derived from SERIES ("8." -> openvox_8x) and overridable with NAV_KEY.
  openvox_nav_key = lambda do
    ENV.fetch('NAV_KEY', "openvox_#{ENV.fetch('SERIES', '8.').gsub(/\D/, '')}x")
  end

  desc 'Generate _data/agent_release_contents/<nav_key>.yml from upstream component pins'
  task :agent_versions do
    require 'puppet_references/release_tables'
    series = ENV.fetch('SERIES', '8.')
    min_version = ENV.fetch('MIN_RELEASE', '8.25.0')
    path = ENV.fetch('AGENT_VERSIONS_DATA', "_data/agent_release_contents/#{openvox_nav_key.call}.yml")
    rows = PuppetReferences::AgentReleaseTable.write_data_file(series:, min_version:, path:)
    puts "Wrote #{rows.size} releases to #{path}"
  end

  desc 'Generate _data/server_release_contents/<nav_key>.yml from upstream component pins'
  task :server_versions do
    require 'puppet_references/release_tables'
    series = ENV.fetch('SERIES', '8.')
    min_version = ENV.fetch('MIN_RELEASE', '8.12.0')
    path = ENV.fetch('SERVER_VERSIONS_DATA', "_data/server_release_contents/#{openvox_nav_key.call}.yml")
    rows = PuppetReferences::ServerReleaseTable.write_data_file(series:, min_version:, path:)
    puts "Wrote #{rows.size} releases to #{path}"
  end

  desc 'Generate _data/openvoxdb_release_contents/<nav_key>.yml from upstream releases'
  task :openvoxdb_versions do
    require 'puppet_references/release_tables'
    series = ENV.fetch('SERIES', '8.')
    min_version = ENV.fetch('MIN_RELEASE', '8.12.0')
    path = ENV.fetch('OPENVOXDB_VERSIONS_DATA', "_data/openvoxdb_release_contents/#{openvox_nav_key.call}.yml")
    rows = PuppetReferences::OpenvoxdbReleaseTable.write_data_file(series:, min_version:, path:)
    puts "Wrote #{rows.size} releases to #{path}"
  end

  desc 'Generate _data/openbolt_release_contents.yml from upstream component pins'
  task :openbolt_versions do
    require 'puppet_references/release_tables'
    # OpenBolt is on its own 5.x line, independent of the OpenVox major, so it uses
    # its own OPENBOLT_SERIES / OPENBOLT_MIN_RELEASE rather than the generic
    # SERIES / MIN_RELEASE. That keeps an OpenVox 9.x regeneration (SERIES=9.) from
    # leaking into OpenBolt, where it would resolve no 9.x releases and abort.
    # The floor is 5.3.0 because OpenBolt SBOMs begin there; 5.1.0/5.2.0 predate the
    # SBOMs and would only be skipped.
    series = ENV.fetch('OPENBOLT_SERIES', '5.')
    min_version = ENV.fetch('OPENBOLT_MIN_RELEASE', '5.3.0')
    path = ENV.fetch('OPENBOLT_VERSIONS_DATA', '_data/openbolt_release_contents.yml')
    rows = PuppetReferences::OpenboltReleaseTable.write_data_file(series:, min_version:, path:)
    puts "Wrote #{rows.size} releases to #{path}"
  end

  desc 'Generate all component-version data files (agent, server, openvoxdb, openbolt)'
  task component_versions: %i[agent_versions server_versions openvoxdb_versions openbolt_versions]

  desc 'Generate _data/supported_platforms.yml from the shared-actions platforms.json'
  task :supported_platforms do
    require 'puppet_references/supported_platforms'
    path = ENV.fetch('SUPPORTED_PLATFORMS_DATA', '_data/supported_platforms.yml')
    data = PuppetReferences::SupportedPlatforms.write_data_file(path:)
    puts "Wrote #{data.values.sum(&:size)} platform rows across #{data.size} series to #{path}"
  end

  task :check do
    puts 'No VERSION given to build references for - using latest tag' unless ENV['VERSION']
    puts "Building into collection #{ENV.fetch('COLLECTION')}" if ENV['COLLECTION']
    puts "Using provided install path #{ENV.fetch('INSTALLPATH')} instead of default" if ENV['INSTALLPATH']
    puts "Using default install path 'references_output'" unless ENV['INSTALLPATH']
  end
end

namespace :test do
  desc 'Check internal links across all built collections (run after `jekyll build`). ' \
       'Override the build dir with SITE_DIR (default: _site).'
  task :links do
    require 'html-proofer'

    site_dir = ENV.fetch('SITE_DIR', '_site')

    # Each collection's `latest` is a symlink to its current stable version, so
    # scoping to `<collection>/latest` checks every page exactly once and follows
    # the current version automatically as new ones are added.
    collections = OpenvoxDocs::VersionedDocs.load_products(Dir.pwd).keys

    # The OpenBolt generated reference pages 404 site-wide until an openbolt
    # release > 5.5.0 ships the front-matter fix (issue #202). CI builds the
    # newest openbolt release tag, which predates that fix, so these nine pages
    # don't render. They're linked from authored pages *and* the shared theme
    # sidebar (rendered on every collection's pages), so ignore them by basename
    # -- matching the absolute path, a relative path, or an anchored form. Remove
    # this once #202 ships in a release.
    openbolt_202_404s = /(?:
      bolt_command_reference|
      bolt_cmdlet_reference|
      bolt_defaults_reference|
      bolt_project_reference|
      bolt_transports_reference|
      bolt_types_reference|
      packaged_modules|
      plan_functions|
      privilege_escalation
    )\.html/x

    dirs = collections.map { |c| File.join(site_dir, c, 'latest') }

    HTMLProofer.check_directories(
      dirs,
      root_dir: site_dir,
      disable_external: true,
      enforce_https: false,
      ignore_empty_alt: true,
      ignore_urls: [openbolt_202_404s],
      checks: ['Links'],
    ).run
  end

  desc 'Validate _data/products.yml: `latest` must name a real version, and ' \
       '`versions` must be ordered newest-first (both are relied on by ' \
       '_includes/version-banner.html and the version selector)'
  task :products_data do
    products = OpenvoxDocs::VersionedDocs.load_products(Dir.pwd)
    errors = []

    products.each do |product_id, product|
      versions = OpenvoxDocs::VersionedDocs.versions(product)
      ids = versions.map { |v| v['id'] }

      errors << "#{product_id}: duplicate version ids (#{ids.join(', ')})" if ids.uniq.length != ids.length

      errors << "#{product_id}: latest '#{product['latest']}' is not one of its versions (#{ids.join(', ')})" unless ids.include?(product['latest'])

      # Every product's pages are in docs/_<product>/, its sidebar in _data/nav/<product>.yml,
      # and the version directories it is assembled into are build output, not tracked.
      errors << "#{product_id}: no docs/_#{product_id}/ directory" unless Dir.exist?("docs/_#{product_id}")
      errors << "#{product_id}: no _data/nav/#{product_id}.yml" if Dir.glob("_data/nav/#{product_id}.{yml,yaml}").empty?
      Dir.glob("docs/_#{product_id}_versions/*").each do |dir|
        errors << "#{dir}: '#{File.basename(dir)}' is not a version of #{product_id}" unless ids.include?(File.basename(dir))
      end
      assembled = OpenvoxDocs::VersionedDocs.assembled_dirs(product_id => product).map { |dir| "docs/#{dir}" }
      tracked = `git ls-files -- #{assembled.join(' ')}`.split("\n")
      errors << "#{product_id}: #{tracked.size} tracked file(s) in build output, e.g. #{tracked.first}" if tracked.any?

      next if product['single_version']

      majors = ids.map { |id| id[/\A\d+/] }
      if majors.any?(&:nil?)
        errors << "#{product_id}: version id(s) don't start with a number (#{ids.join(', ')}), can't check ordering"
      elsif majors.map(&:to_i) != majors.map(&:to_i).sort.reverse
        errors << "#{product_id}: versions must be newest-first by id (got #{ids.join(', ')})"
      end
    end

    if errors.any?
      warn "_data/products.yml failed validation:\n  - #{errors.join("\n  - ")}"
      exit 1
    end

    puts '_data/products.yml: versions, latest references, and docs layout OK'
  end
end

# Maintenance tasks for the versioned documentation. See "Documentation
# versions" in MAINTAINING.md.
namespace :docs do
  versioned = OpenvoxDocs::VersionedDocs

  product_for = lambda do |product_id|
    versioned.load_products(Dir.pwd)[product_id] or abort "#{product_id}: not a product in _data/products.yml"
  end

  # Files an older version keeps its own copy of, relative to its directory.
  own_pages = lambda do |product_id, version|
    dir = versioned.version_dir('docs', product_id, version)
    return [] unless Dir.exist?(dir)

    Dir.glob('**/*', base: dir).select { |rel| File.file?(File.join(dir, rel)) }.sort
  end

  desc 'Before changing pages for the newest version only, keep the current copy for every older version ' \
       "that doesn't have its own: rake 'docs:preserve[openvox,page.md,...]'. With no pages, keeps every " \
       'page that some older version already has its own copy of (the pages that differ per version).'
  task :preserve, [:product] do |_task, args|
    product_id = args[:product]
    product = product_for.call(product_id)
    older = versioned.versions(product).drop(1).reject { |version| version['frozen'] }
    abort "#{product_id} has no older, unfrozen version to keep pages for" if older.empty?

    pages = args.extras
    named = pages.any?
    pages = older.flat_map { |version| own_pages.call(product_id, version) }.uniq.sort unless named
    abort "no older version of #{product_id} has its own pages yet; name the pages to keep" if pages.empty?

    kept = 0
    pages.each do |page|
      src = File.join('docs', "_#{product_id}", page)
      unless File.file?(src)
        abort "#{src} does not exist" if named
        next
      end

      older.each do |version|
        dest = File.join(versioned.version_dir('docs', product_id, version), page)
        next if File.exist?(dest) || !versioned.published?(src, versioned.major(version))

        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src, dest)
        sh 'git', 'add', dest
        kept += 1
      end
    end
    puts "Kept #{kept} page(s) for older versions. Now edit the pages in docs/_#{product_id}/."
  end

  desc "Snapshot a version that is no longer maintained: rake 'docs:freeze[openvox,8x]'"
  task :freeze, [:product, :version] do |_task, args|
    product_id = args[:product]
    product = product_for.call(product_id)
    version = versioned.versions(product).find { |v| v['id'] == args[:version] }
    abort "#{product_id}: no version #{args[:version]}" unless version
    abort "#{product_id} #{version['id']} is already frozen" if version['frozen']

    # Copy every shared page this version publishes into its own directory.
    own_dir = versioned.version_dir('docs', product_id, version)
    files = versioned.page_sets('docs', product_id, product)[version]
    files.each do |rel, src|
      dest = File.join(own_dir, rel)
      next if File.exist?(dest)

      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
    end

    # Write out the version's sidebar so later nav changes don't reach it.
    shared_nav = Dir.glob("_data/nav/#{product_id}.{yml,yaml}").first or abort "no _data/nav/#{product_id}.yml"
    navs = { product_id => YAML.load_file(shared_nav) }
    versioned.build_navs(navs, 'docs', product_id, product)
    nav_file = "_data/nav/#{versioned.label(version)}.yml"
    File.write(nav_file, navs[versioned.label(version)].to_yaml(line_width: -1))

    # Mark it frozen in products.yml.
    data = File.read('_data/products.yml')
    block = data[/^#{Regexp.escape(product_id)}:\n(?:[ #].*\n|\n)*/] or abort 'product not found in products.yml'
    entry = /^(\s*)- id: #{Regexp.escape(version['id'])}\n/
    frozen = data.sub(block, block.sub(entry) { "#{Regexp.last_match(0)}#{Regexp.last_match(1)}  frozen: true\n" })
    abort "couldn't find '- id: #{version['id']}' under #{product_id} in _data/products.yml; add `frozen: true` by hand" if frozen == data
    File.write('_data/products.yml', frozen)

    sh 'git', 'add', own_dir, nav_file, '_data/products.yml'
    puts "#{product_id} #{version['id']} is frozen. Also pin its `ref:` to its final tag if it has one."
  end

  desc 'List each older version\'s own pages, flagging any that match the shared page again'
  task :status do
    versioned.load_products(Dir.pwd).each do |product_id, product|
      versioned.versions(product).drop(1).each do |version|
        dir = versioned.version_dir('docs', product_id, version)
        pages = own_pages.call(product_id, version)
        puts "#{product_id} #{version['id']}#{' (frozen)' if version['frozen']}: #{pages.size} own files"
        next if version['frozen']

        pages.each do |rel|
          shared = File.join('docs', "_#{product_id}", rel)
          note = if !File.exist?(shared) then 'only in this version'
                 elsif FileUtils.identical?(shared, File.join(dir, rel)) then 'SAME AS SHARED, can be deleted'
                 end
          puts "  #{rel}#{" (#{note})" if note}"
        end
      end
    end
  end
end
