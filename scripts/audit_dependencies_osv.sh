#!/usr/bin/env bash

# Exact-version vulnerability audit for both dependency layers:
#   1. Dart/Flutter packages resolved by pub
#   2. Maven artifacts resolved in the Play release runtime classpath
#
# OSV only reports vulnerabilities known to its current data sources. A clean
# result is evidence of "no known OSV finding at scan time", not proof that a
# dependency is vulnerability-free.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/korubeni-osv-audit.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

query_osv() {
    local label="$1"
    local query_file="$2"
    local response_file="$TMP_DIR/$label-response.json"

    curl --fail --silent --show-error --location \
        --retry 3 \
        --retry-all-errors \
        --connect-timeout 10 \
        --max-time 90 \
        --proto '=https' \
        --tlsv1.2 \
        --header 'Content-Type: application/json' \
        --data-binary "@$query_file" \
        --output "$response_file" \
        'https://api.osv.dev/v1/querybatch'

    ruby -rjson -e '
      queries = JSON.parse(File.read(ARGV[0])).fetch("queries")
      results = JSON.parse(File.read(ARGV[1])).fetch("results")
      abort "OSV response count mismatch" unless results.length == queries.length

      findings = []
      results.each_with_index do |result, index|
        next if result.fetch("vulns", []).empty?
        package = queries[index].fetch("package")
        coordinate = "#{package.fetch("ecosystem")}:#{package.fetch("name")}@#{queries[index].fetch("version")}"
        ids = result.fetch("vulns").map { |vulnerability| vulnerability.fetch("id") }.uniq.sort
        findings << "#{coordinate}: #{ids.join(",")}"
      end

      if findings.any?
        warn "Known OSV vulnerabilities found:"
        findings.each { |finding| warn "  #{finding}" }
        exit 1
      end

      puts "PASS #{queries.length} exact package versions: no known OSV findings"
    ' "$query_file" "$response_file"
}

PUB_DEPS="$TMP_DIR/pub-deps.json"
PUB_QUERY="$TMP_DIR/pub-query.json"
MAVEN_REPORT="$TMP_DIR/maven-dependencies.txt"
MAVEN_QUERY="$TMP_DIR/maven-query.json"

cd "$REPO_ROOT"
flutter pub deps --json > "$PUB_DEPS"
ruby -rjson -e '
  document = JSON.parse(File.read(ARGV[0]))
  root_package = document.fetch("root")
  queries = document.fetch("packages").each_with_object([]) do |package, output|
    version = package["version"]
    next if package.fetch("name") == root_package
    next if version.nil? || version.empty?
    output << {
      package: {name: package.fetch("name"), ecosystem: "Pub"},
      version: version,
    }
  end
  puts JSON.generate({queries: queries.uniq})
' "$PUB_DEPS" > "$PUB_QUERY"
query_osv pub "$PUB_QUERY"

(
    cd "$REPO_ROOT/android"
    ./gradlew app:dependencies \
        --configuration playReleaseRuntimeClasspath \
        --console=plain
) > "$MAVEN_REPORT"

ruby -rjson -e '
  coordinates = {}
  File.foreach(ARGV[0]) do |line|
    match = line.match(/([A-Za-z0-9_.-]+):([A-Za-z0-9_.-]+):([A-Za-z0-9_.+\-]+)(?:\s+->\s+([A-Za-z0-9_.+\-]+))?/)
    next unless match
    name = "#{match[1]}:#{match[2]}"
    version = match[4] || match[3]
    next if name.start_with?("project:") || version == "unspecified"
    coordinates["#{name}@#{version}"] = {
      package: {name: name, ecosystem: "Maven"},
      version: version,
    }
  end
  puts JSON.generate({queries: coordinates.values})
' "$MAVEN_REPORT" > "$MAVEN_QUERY"
query_osv maven "$MAVEN_QUERY"

echo "Dependency audit complete. OSV coverage limitations still apply."
