#!/bin/bash

me=$(basename "$0")

msg() {
      echo 1>&2 "$me": "$@"
}

die() {
      msg "$@"
      exit 2
}

if [ $# -lt 1 ] || [ $# -gt 2 ] ; then
      cat <<__EOF__
usage:   $me tier  [Public]
example: $me CentOS
example: $me Web    Public
__EOF__
      exit 1
fi

tier=$1
public=$2

[ -n "$public" ] && public=Public

[ -n "$WORKSPACE" ] || die "missing env var WORKSPACE"

header="$WORKSPACE"/gobetween/gobetween.toml.header

[ -r "$header" ] || die "missing header file: $header"

issue() {
	"$WORKSPACE"/cloudcenter/ccc-tier-addresses.sh "$tier" "$public" | while read i; do
		echo "\"$i:8080\","
	done
}

#  static_list = [
#      "localhost:8080",
#      "localhost:8080"
#  ]

output="$WORKSPACE"/gobetween/gobetween.toml

cat "$header" > "$output"
echo 'static_list = [' >> "$output"
issue >> "$output"
sed -i '$ s/,$//' "$output" ;# remove last comma
echo ']' >> "$output"

msg gobetween config issued to: "$output"

