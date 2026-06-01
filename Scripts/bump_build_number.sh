#!/bin/sh

set -eu

xcconfig="${SRCROOT}/Config/Version.xcconfig"

if [ ! -f "$xcconfig" ]; then
  echo "error: missing ${xcconfig}" >&2
  exit 1
fi

ruby - <<'RUBY' "$xcconfig"
path = ARGV.fetch(0)
lines = File.readlines(path, chomp: true)
index = lines.index { |line| line.match?(/^\s*CURRENT_PROJECT_VERSION\s*=\s*\d+\s*$/) }

abort("error: CURRENT_PROJECT_VERSION not found in #{path}") unless index

current = lines[index][/(\d+)/, 1].to_i
lines[index] = "CURRENT_PROJECT_VERSION = #{current + 1}"

File.write(path, lines.join("\n") + "\n")
RUBY
