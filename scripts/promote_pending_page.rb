#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "pathname"

ROOT = File.expand_path("..", __dir__)
PENDING_ROOT = File.join(ROOT, "pending")
IMAGES_ROOT = File.join(ROOT, "images")


def usage
  puts "Usage: ruby scripts/promote_pending_page.rb <pending-subfolder>"
  puts "Example: ruby scripts/promote_pending_page.rb cohoots-phoenix"
end


def relative_images_path(from_dir)
  Pathname.new(IMAGES_ROOT).relative_path_from(Pathname.new(from_dir)).to_s
end


def absolute_url?(url)
  url.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|/|#)}i)
end


def rewrite_image_url(url, images_prefix)
  return url if absolute_url?(url)

  match = url.match(%r{\A(?:\./|\.\./)*images/(.+)\z})
  return url unless match

  "#{images_prefix}/#{match[1]}"
end


def update_html_image_paths(target_dir)
  html_files = Dir.glob(File.join(target_dir, "**", "*.html"))
  changed_files = []

  html_files.each do |file|
    original = File.read(file)
    images_prefix = relative_images_path(File.dirname(file))

    updated = original.gsub(/((?:src|href)\s*=\s*["'])([^"']+)(["'])/i) do
      prefix, url, suffix = Regexp.last_match.captures
      "#{prefix}#{rewrite_image_url(url, images_prefix)}#{suffix}"
    end

    next if updated == original

    File.write(file, updated)
    changed_files << file
  end

  changed_files
end


slug = ARGV[0]
if slug.nil? || slug.strip.empty?
  usage
  exit 1
end

slug = slug.strip
source_dir = File.join(PENDING_ROOT, slug)
destination_dir = File.join(ROOT, slug)

unless Dir.exist?(source_dir)
  abort "Pending folder not found: #{source_dir}"
end

if Dir.exist?(destination_dir)
  abort "Destination already exists: #{destination_dir}"
end

unless Dir.exist?(IMAGES_ROOT)
  abort "Images folder not found: #{IMAGES_ROOT}"
end

FileUtils.mv(source_dir, destination_dir)
changed = update_html_image_paths(destination_dir)

puts "Moved: #{source_dir} -> #{destination_dir}"
puts "Updated image links in #{changed.length} HTML file(s)."
changed.each { |file| puts " - #{file}" }
