#!/usr/bin/env bash
set -euo pipefail

# Convert xccov output from one or more .xcresult bundles into Sonar generic coverage XML.
# Usage (preferred):
#   xccov_to_sonar_generic.sh <output.xml> <repo-root> <xcresult> [<xcresult> ...]
# Legacy usage (still supported):
#   xccov_to_sonar_generic.sh <xcresult> <output.xml> <repo-root>

usage() {
  echo "usage: xccov_to_sonar_generic.sh <output-xml> <repo-root> <xcresult> [<xcresult> ...]" >&2
  echo "   or: xccov_to_sonar_generic.sh <xcresult> <output-xml> <repo-root>" >&2
}

output_xml=""
repo_root=""
xcresults=()

if [[ $# -eq 3 && "$1" == *.xcresult ]]; then
  xcresults=("$1")
  output_xml="$2"
  repo_root="$3"
elif [[ $# -ge 3 ]]; then
  output_xml="$1"
  repo_root="$2"
  shift 2
  xcresults=("$@")
else
  usage
  exit 2
fi

for xcresult_path in "${xcresults[@]}"; do
  if [[ ! -d "$xcresult_path" || "$xcresult_path" != *.xcresult ]]; then
    echo "invalid xcresult path: $xcresult_path" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "$output_xml")"

raw_rows_tmp="$(mktemp -t xccov_raw)"
merged_rows_tmp="$(mktemp -t xccov_merged)"
sorted_rows_tmp="$(mktemp -t xccov_sorted)"
trap 'rm -f "$raw_rows_tmp" "$merged_rows_tmp" "$sorted_rows_tmp"' EXIT

for xcresult_path in "${xcresults[@]}"; do
  xcrun xccov view --archive "$xcresult_path" | awk -v repo_root="$repo_root" '
  BEGIN {
    current_file = ""
    in_branch = 0
  }

  function normalize_path(path) {
    gsub(/\r$/, "", path)
    if (index(path, repo_root "/") == 1) {
      return substr(path, length(repo_root) + 2)
    }
    return path
  }

  function emit_line(file_path, line_no, covered, branches_total, branches_covered) {
    if (file_path == "" || line_no == "") {
      return
    }
    if (branches_total < 0) {
      branches_total = -1
      branches_covered = -1
    }
    printf "%s\t%s\t%d\t%d\t%d\n", file_path, line_no, covered, branches_total, branches_covered
  }

  /:$/ && $0 !~ /^ *[0-9]+:/ {
    raw_path = substr($0, 1, length($0)-1)
    current_file = normalize_path(raw_path)
    in_branch = 0
    next
  }

  /^ *[0-9]+: [0-9]+ \[$/ {
    line_no = $1
    sub(/:$/, "", line_no)
    exec_count = $2 + 0
    branch_total = 0
    branch_covered = 0
    branch_line_no = line_no
    branch_line_covered = (exec_count > 0 ? 1 : 0)
    in_branch = 1
    next
  }

  /^\([0-9]+, [0-9]+, [0-9]+\)$/ {
    if (in_branch) {
      tuple = $0
      gsub(/[()]/, "", tuple)
      split(tuple, vals, ", ")
      c1 = vals[2] + 0
      c2 = vals[3] + 0
      branch_total += 2
      if (c1 > 0) branch_covered++
      if (c2 > 0) branch_covered++
    }
    next
  }

  /^\]$/ {
    if (in_branch) {
      if (branch_total > 0) {
        emit_line(current_file, branch_line_no, branch_line_covered, branch_total, branch_covered)
      } else {
        emit_line(current_file, branch_line_no, branch_line_covered, -1, -1)
      }
      in_branch = 0
    }
    next
  }

  /^ *[0-9]+: \*$/ {
    next
  }

  /^ *[0-9]+: 0$/ {
    line_no = $1
    sub(/:$/, "", line_no)
    emit_line(current_file, line_no, 0, -1, -1)
    next
  }

  /^ *[0-9]+: [1-9][0-9]*$/ {
    line_no = $1
    sub(/:$/, "", line_no)
    emit_line(current_file, line_no, 1, -1, -1)
    next
  }
  ' >> "$raw_rows_tmp"
done

sort -t $'\t' -k1,1 -k2,2n "$raw_rows_tmp" > "$sorted_rows_tmp"

awk -F "\t" '
function flush() {
  if (current_key != "") {
    if (current_branches_to_cover >= 0) {
      if (current_covered_branches > current_branches_to_cover) {
        current_covered_branches = current_branches_to_cover
      }
      printf "%s\t%s\t%d\t%d\t%d\n", current_file, current_line, current_covered, current_branches_to_cover, current_covered_branches
    } else {
      printf "%s\t%s\t%d\t-1\t-1\n", current_file, current_line, current_covered
    }
  }
}

{
  file = $1
  line = $2
  covered = $3 + 0
  branches_to_cover = $4 + 0
  covered_branches = $5 + 0

  key = file SUBSEP line
  if (current_key != "" && key != current_key) {
    flush()
    current_key = ""
  }

  if (current_key == "") {
    current_key = key
    current_file = file
    current_line = line
    current_covered = covered
    current_branches_to_cover = branches_to_cover
    current_covered_branches = (covered_branches >= 0 ? covered_branches : 0)
    next
  }

  if (covered > current_covered) {
    current_covered = covered
  }
  if (branches_to_cover >= 0) {
    if (current_branches_to_cover < 0 || branches_to_cover > current_branches_to_cover) {
      current_branches_to_cover = branches_to_cover
    }
    if (covered_branches > current_covered_branches) {
      current_covered_branches = covered_branches
    }
  }
}

END {
  flush()
}
' "$sorted_rows_tmp" > "$merged_rows_tmp"

awk -F "\t" '
BEGIN {
  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  print "<coverage version=\"1\">"
  current_file = ""
}

function xml_escape(path) {
  gsub(/&/, "\\&amp;", path)
  gsub(/</, "\\&lt;", path)
  gsub(/>/, "\\&gt;", path)
  gsub(/\"/, "\\&quot;", path)
  return path
}

function close_file_if_needed() {
  if (current_file != "") {
    print "  </file>"
    current_file = ""
  }
}

{
  file_path = $1
  line_no = $2
  covered = ($3 + 0) > 0 ? "true" : "false"
  branches_to_cover = $4 + 0
  covered_branches = $5 + 0

  if (file_path != current_file) {
    close_file_if_needed()
    current_file = file_path
    print "  <file path=\"" xml_escape(current_file) "\">"
  }

  if (branches_to_cover >= 0) {
    printf "    <lineToCover lineNumber=\"%s\" covered=\"%s\" branchesToCover=\"%d\" coveredBranches=\"%d\"/>\n", line_no, covered, branches_to_cover, covered_branches
  } else {
    printf "    <lineToCover lineNumber=\"%s\" covered=\"%s\"/>\n", line_no, covered
  }
}

END {
  close_file_if_needed()
  print "</coverage>"
}
' "$merged_rows_tmp" > "$output_xml"