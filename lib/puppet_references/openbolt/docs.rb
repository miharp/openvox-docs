# frozen_string_literal: true

require 'puppet_references'
require 'fileutils'

module PuppetReferences
  module Openbolt
    class Docs < PuppetReferences::Reference
      OUTPUT_DIR = PuppetReferences::OUTPUT_DIR + '_openbolt_latest'
      DOCS_SOURCE = PuppetReferences::BOLT_DIR + 'documentation'

      # README.md is repo housekeeping, not a user-facing doc page.
      SKIP_FILES = %w[README.md].freeze

      def initialize(*)
        @latest = '/openbolt/latest'
        super
      end

      def build_all
        OUTPUT_DIR.mkpath
        puts 'OpenBolt Docs: Building all...'
        copy_docs
        puts 'OpenBolt Docs: Done!'
      end

      def copy_docs
        Pathname.glob(DOCS_SOURCE + '*.md').each do |file|
          next if SKIP_FILES.include?(file.basename.to_path)

          munge_and_copy_doc_file(file)
        end
        Pathname.glob(DOCS_SOURCE + '*.{png,jpg,gif,svg}').each do |img|
          FileUtils.cp(img.to_path, (OUTPUT_DIR + img.basename).to_path)
        end
        write_index
      end

      # bolt.md is the welcome/overview page; writing it as index.md gives
      # /openbolt/latest/ a landing page instead of a directory listing.
      def write_index
        source = DOCS_SOURCE + 'bolt.md'
        content = source.read
        title = extract_title(content) || 'OpenBolt'
        header_data = { title: title, canonical: "#{@latest}/index.html" }
        body = strip_leading_h1(content)
        (OUTPUT_DIR + 'index.md').open('w') { |f| f.write(make_header(header_data) + body) }
      end

      # Upstream bolt docs are plain markdown with no frontmatter; Jekyll
      # requires it to treat files as collection pages.
      def munge_and_copy_doc_file(file)
        content = file.read
        title = extract_title(content) || humanize(file.basename('.md').to_path)
        shortname = file.basename('.md').to_path
        header_data = {
          title: title,
          canonical: "#{@latest}/#{shortname}.html",
        }
        body = strip_leading_h1(content)
        dest = OUTPUT_DIR + file.basename
        dest.open('w') { |f| f.write(make_header(header_data) + body) }
      end

      # Overrides the base class version, which emits "generated from OpenVox
      # source code" and re-adds an H1 — both wrong for OpenBolt pages.
      def make_header(header_data)
        require 'yaml'
        data = {
          'layout' => 'default',
          'built_from_commit' => @commit,
          'title' => header_data[:title],
          'canonical' => header_data[:canonical],
        }
        generated_at = "> **NOTE:** This page was generated from the OpenBolt source code on #{Time.now}"
        YAML.dump(data) + "---\n\n" + generated_at + "\n\n"
      end

      private

      def extract_title(content)
        match = content.match(/^#\s+(.+)$/)
        match[1].strip if match
      end

      # The theme renders the H1 from frontmatter `title:`, so the source H1
      # would appear twice if left in the body.
      def strip_leading_h1(content)
        content.sub(/\A#[^\n]*\n+/, '')
      end

      def humanize(filename)
        filename.gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ')
      end
    end
  end
end
