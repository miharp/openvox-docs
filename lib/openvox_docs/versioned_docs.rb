# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'yaml'

module OpenvoxDocs
  # Everything about documentation versions is driven by _data/products.yml.
  # This module derives the rest at build time, so adding a major or promoting
  # one to `latest` is an edit to that one file.
  #
  # For every product it registers the Jekyll collections and their front
  # matter defaults (one per version, plus the `_<product>_latest` alias),
  # points the `docs/_<product>_latest` symlink at the `latest:` version, and
  # builds the sidebar's nav map and the product bar's collection lists.
  #
  # Each version's collection directory is assembled, not committed:
  #
  #   docs/_openvox/                 pages for the newest version, shared by
  #                                  every version that doesn't replace them
  #   docs/_openvox_versions/8x/     8.x's copies of pages that differ from the
  #                                  shared ones, and pages only 8.x has
  #   docs/_openvox_8x/              assembled: shared pages + 8.x's pages
  #                                  (gitignored build output)
  #
  # A shared page with `since: 9` in its front matter is left out of older
  # versions. A version marked `frozen: true` is assembled from its own
  # directory only, which `rake docs:freeze` fills with a full snapshot.
  #
  # The sidebar comes from _data/nav/<product>.yml, with `{major}` in link
  # text replaced per version and links to pages a version doesn't have
  # removed. A _data/nav/<product>_<id>.yml file replaces it for that version
  # (frozen versions get one from `rake docs:freeze`).
  module VersionedDocs
    PAGE_EXTS = %w[.md .markdown].freeze
    MANIFEST = '.assembled'

    module_function

    # -- products.yml --------------------------------------------------------

    def load_products(source)
      fill_defaults(YAML.safe_load_file(File.join(source, '_data', 'products.yml')) || {})
    end

    # Derives each version's `label`, `collection`, and `base` from its id
    # ("9x" -> "9.x", "_openvox_9x", "/openvox/9.x/") unless set explicitly.
    def fill_defaults(products)
      products.each do |product_id, product|
        Array(product['versions']).each do |version|
          version['label'] ||= version['id'].sub(/\A(\d+)x\z/, '\1.x')
          version['collection'] ||= "_#{product_id}_#{version['id']}"
          version['base'] ||= "/#{product_id}/#{version['label']}/"
        end
      end
    end

    def versions(product)
      Array(product['versions'])
    end

    def latest_version(product)
      versions(product).find { |version| version['id'] == product['latest'] }
    end

    def label(version)
      version['collection'].delete_prefix('_')
    end

    def major(version)
      version['id'].to_i
    end

    def versioned?(product)
      !product['single_version']
    end

    # -- Jekyll configuration ------------------------------------------------

    # Adds each version's collection and front matter defaults to the site
    # config. `layout: default` covers generated pages whose front matter has
    # no layout (OpenBolt's); authored pages set their own. Entries already in
    # _config.yml win, and repeated calls (every `jekyll serve` regeneration)
    # add nothing new.
    def register(config, products)
      collections = (config['collections'] ||= {})
      defaults = (config['defaults'] ||= [])

      products.each do |product_id, product|
        if versioned?(product) && latest_version(product)
          add_collection(collections, defaults, "#{product_id}_latest", "/#{product_id}/latest/",
                         label(latest_version(product)))
        end
        versions(product).reverse_each do |version|
          add_collection(collections, defaults, label(version), version['base'], label(version))
        end
      end
    end

    def add_collection(collections, defaults, name, base, nav)
      collections[name] ||= { 'output' => true, 'permalink' => "#{base}:path:output_ext" }
      return if defaults.any? { |d| d.dig('scope', 'type') == name && d.dig('values', 'nav') }

      defaults << { 'scope' => { 'path' => '', 'type' => name }, 'values' => { 'nav' => nav, 'layout' => 'default' } }
    end

    # -- Assembly ------------------------------------------------------------

    def assemble(docs_dir, products)
      products.each do |product_id, product|
        page_sets(docs_dir, product_id, product).each do |version, files|
          write(File.join(docs_dir, version['collection']), files)
        end
        link_latest(docs_dir, product_id, product) if versioned?(product)
      end
    end

    # Collection directories the build writes, relative to the collections dir.
    def assembled_dirs(products)
      products.flat_map do |product_id, product|
        ["_#{product_id}_latest", *versions(product).map { |version| version['collection'] }]
      end.uniq
    end

    def shared_dir(docs_dir, product_id)
      File.join(docs_dir, "_#{product_id}")
    end

    def version_dir(docs_dir, product_id, version)
      File.join(docs_dir, "_#{product_id}_versions", version['id'])
    end

    # Maps each version to {relative path => source file}. A version's own
    # page replaces the shared page at the same path.
    def page_sets(docs_dir, product_id, product)
      versions(product).to_h do |version|
        files = {}
        shared = shared_dir(docs_dir, product_id)
        collect(files, shared) { |path| published?(path, major(version)) } unless version['frozen']
        collect(files, version_dir(docs_dir, product_id, version)) { true }
        [version, files]
      end
    end

    def collect(files, dir)
      return unless Dir.exist?(dir)

      Dir.glob('**/*', base: dir).each do |rel|
        path = File.join(dir, rel)
        files[rel] = path if File.file?(path) && yield(path)
      end
    end

    def published?(path, major)
      return true unless PAGE_EXTS.include?(File.extname(path))

      since = front_matter(path)['since']
      since.nil? || major >= since.to_i
    end

    def front_matter(path)
      match = File.read(path).match(/\A---\s*\n(.*?)\n---\s*$/m)
      data = match && YAML.safe_load(match[1], permitted_classes: [Date, Time])
      data.is_a?(Hash) ? data : {}
    rescue Psych::Exception
      {}
    end

    # Copies only files whose content changed, keeping the source's mtime (the
    # theme's "Last updated" date), so `jekyll serve` doesn't rebuild in a
    # loop. Copies are read-only so an editor warns before anyone edits build
    # output instead of its source. Files from the previous assembly whose
    # source is gone are removed; anything else in the directory (generated
    # reference pages) is left alone.
    def write(target, files)
      FileUtils.mkdir_p(target)
      manifest = File.join(target, MANIFEST)
      previous = File.exist?(manifest) ? File.read(manifest).split("\n") : []

      files.each do |rel, src|
        dest = File.join(target, rel)
        next if File.exist?(dest) && FileUtils.identical?(src, dest)

        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.rm_f(dest)
        FileUtils.cp(src, dest, preserve: true)
        File.chmod(0o444, dest)
      end

      (previous - files.keys).each { |rel| FileUtils.rm_f(File.join(target, rel)) }
      listing = files.keys.sort.join("\n")
      File.write(manifest, listing) unless previous.sort.join("\n") == listing
    end

    def link_latest(docs_dir, product_id, product)
      latest = latest_version(product) or return
      link = File.join(docs_dir, "_#{product_id}_latest")
      target = latest['collection']
      return if File.symlink?(link) && File.readlink(link) == target

      FileUtils.rm_f(link) if File.symlink?(link)
      raise "#{link} is a real directory, but the build creates it as a symlink; remove it" if File.exist?(link)

      File.symlink(target, link)
    rescue NotImplementedError, SystemCallError => e
      # Windows without symlink rights: build everything except /latest/.
      warn "versioned_docs: can't link #{link} -> #{target} (#{e.message}); /#{product_id}/latest/ will be missing"
    end

    # -- Site data -------------------------------------------------------------

    def decorate(site)
      products = fill_defaults(site.data['products'] || {})
      site.data['nav_map'] = nav_map(products)
      fill_navigation(site.data['navigation'], products)
      products.each do |product_id, product|
        set_major(site, product_id, product)
        build_navs(site.data['nav'] ||= {}, site.collections_path, product_id, product)
      end
    end

    def nav_map(products)
      products.flat_map do |product_id, product|
        versions(product).map do |version|
          collections = [label(version)]
          base = version['base']
          if versioned?(product) && version['id'] == product['latest']
            collections.unshift("#{product_id}_latest")
            base = "/#{product_id}/latest/"
          end
          { 'nav_key' => label(version), 'collections' => collections.join('|'), 'base' => base }
        end
      end
    end

    # The product bar marks a product active on any of its collections.
    def fill_navigation(navigation, products)
      Array(navigation).each do |item|
        product_id, product = products.find { |id, _| item['url'] == "/#{id}/latest/" }
        next unless product

        latest = versioned?(product) ? ["#{product_id}_latest"] : []
        item['collections'] = latest + versions(product).map { |v| label(v) }
      end
    end

    # `page.major` for "OpenVox {{ page.major }}.x" and `{% if page.major >= 9 %}`.
    def set_major(site, product_id, product)
      versions(product).each do |version|
        tag(site.collections[label(version)], major(version))
      end
      latest = latest_version(product)
      tag(site.collections["#{product_id}_latest"], major(latest)) if latest
    end

    def tag(collection, major)
      collection&.docs&.each { |doc| doc.data['major'] ||= major }
    end

    # Builds each version's sidebar from the product's shared nav unless the
    # version has its own nav file. A link is dropped when the version lacks a
    # page that another version has, so generated reference pages (which no
    # version's sources include) are never dropped.
    def build_navs(navs, docs_dir, product_id, product)
      shared = navs[product_id] or return
      sets = page_sets(docs_dir, product_id, product).transform_values { |files| page_links(files.keys) }
      all_pages = sets.values.flatten.uniq

      sets.each do |version, pages|
        navs[label(version)] ||= prune(shared, all_pages - pages, major(version).to_s)
      end
    end

    def page_links(paths)
      paths.select { |rel| PAGE_EXTS.include?(File.extname(rel)) }.map { |rel| rel.sub(/\.(md|markdown)\z/, '.html') }
    end

    def prune(items, missing, major)
      items.filter_map do |item|
        item = item.merge('text' => item['text'].to_s.gsub('{major}', major))
        if item['items']
          children = prune(item['items'], missing, major)
          children.empty? ? nil : item.merge('items' => children)
        elsif item['link'] && missing.include?(item['link'].sub(/#.*/, ''))
          nil
        else
          item
        end
      end
    end
  end
end
