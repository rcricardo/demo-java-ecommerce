#!/bin/bash

me=$(basename "$0")

msg() {
	echo 1>&2 "$me": "$@"
}

die() {
	msg "$@"
	exit 2
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	cat <<__EOF__
usage:   $me tiers    [Public]
example: $me App       Public
example: $me Balancer  Public
__EOF__
	exit 1
fi

tier=$1
public=$2

[ -n "$public" ] && public=Public

[ -n "$WORKSPACE" ] || die "missing env var WORKSPACE"

# scan IPs from Cloud Center tier
grep -E "CliqrTier_${tier}.*_${public}IP" < "$WORKSPACE"/userenv | awk -F= '{ print $2 }' | sed -e 's/,/\n/' | {
	count=0

	while read -r i; do

		((count++))
		msg "found ip $count for tier $tier: $i"

		# show ip
		echo $i
	done

	msg "ip count for tier $tier: $count"

	[ "$count" -gt 0 ] || die "bad ip count for tier $tier: $count"
}
