# frozen_string_literal: true

require_relative '../lib/openvox_docs/versioned_docs'

# Derives collections, nav, and assembled version directories from
# _data/products.yml. See lib/openvox_docs/versioned_docs.rb and MAINTAINING.md.

# Runs before every build and `jekyll serve` regeneration, after Jekyll has
# cleared its collections and before it reads them.
Jekyll::Hooks.register :site, :after_reset do |site|
  products = OpenvoxDocs::VersionedDocs.load_products(site.source)
  OpenvoxDocs::VersionedDocs.register(site.config, products)
  OpenvoxDocs::VersionedDocs.assemble(site.collections_path, products)
end

Jekyll::Hooks.register :site, :post_read do |site|
  OpenvoxDocs::VersionedDocs.decorate(site)
end

# `jekyll serve` rebuilds whenever a watched file changes. The assembled
# directories only change because a build just wrote them, so ignore them;
# otherwise every edit to a shared page triggers a second, redundant rebuild.
begin
  require 'jekyll-watch'

  module OpenvoxDocs
    module IgnoreAssembledDirs
      def listen_ignore_paths(options)
        products = VersionedDocs.load_products(options['source'])
        dirs = VersionedDocs.assembled_dirs(products).map { |dir| File.join(options['collections_dir'].to_s, dir) }
        super + dirs.map { |dir| %r{^#{Regexp.escape(dir)}/} }
      end
    end
  end

  Jekyll::Watcher.singleton_class.prepend(OpenvoxDocs::IgnoreAssembledDirs)
rescue LoadError
  nil
end
