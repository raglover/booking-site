#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "pathname"

ROOT = File.expand_path("..", __dir__)
PENDING_ROOT = File.join(ROOT, "pending")
COMPLETED_ROOT = File.join(ROOT, "completed")
IMAGES_ROOT = File.join(ROOT, "images")
RESERVED_ROOT_DIRS = %w[pending completed images scripts .git].freeze


def usage
  puts "Usage: ruby scripts/promote_pending_page.rb <promote|demote> <slug>"
  puts "       ruby scripts/promote_pending_page.rb <slug>"
  puts ""
  puts "Examples:"
  puts "  ruby scripts/promote_pending_page.rb promote cohoots-phoenix"
  puts "  ruby scripts/promote_pending_page.rb demote cohoots-mesa"
  puts "  ruby scripts/promote_pending_page.rb cohoots-phoenix   # defaults to promote"
end


def validate_slug!(slug)
  abort "Slug cannot be empty." if slug.nil? || slug.strip.empty?

  cleaned = slug.strip
  if cleaned.include?("/") || cleaned.include?("\\") || cleaned.include?("..")
    abort "Invalid slug. Use just the folder name, for example: cohoots-phoenix"
  end

  cleaned
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


if ARGV.empty?
  usage
  exit 1
end

if ARGV.length == 1
  command = "promote"
  slug = ARGV[0]
else
  command = ARGV[0].to_s.downcase
  slug = ARGV[1]
end

unless %w[promote demote].include?(command)
  usage
  abort "Unknown command: #{command}"
end

slug = validate_slug!(slug)

if command == "promote"
  source_dir = File.join(PENDING_ROOT, slug)
  destination_dir = File.join(ROOT, slug)

  unless Dir.exist?(source_dir)
    abort "Pending folder not found: #{source_dir}"
  end

  if Dir.exist?(destination_dir)
    abort "Destination already exists: #{destination_dir}"
  end
else
  if RESERVED_ROOT_DIRS.include?(slug)
    abort "Refusing to demote reserved root folder: #{slug}"
  end

  source_dir = File.join(ROOT, slug)
  destination_dir = File.join(COMPLETED_ROOT, slug)

  unless Dir.exist?(source_dir)
    abort "Root folder not found: #{source_dir}"
  end

  if Dir.exist?(destination_dir)
    abort "Destination already exists: #{destination_dir}"
  end

  FileUtils.mkdir_p(COMPLETED_ROOT)
end


unless Dir.exist?(IMAGES_ROOT)
  abort "Images folder not found: #{IMAGES_ROOT}"
end

FileUtils.mv(source_dir, destination_dir)
changed = update_html_image_paths(destination_dir)

puts "Moved: #{source_dir} -> #{destination_dir}"
puts "Updated image links in #{changed.length} HTML file(s)."
changed.each { |file| puts " - #{file}" }
