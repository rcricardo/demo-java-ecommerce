#!/bin/bash

me=$(basename "$0")

msg() {
	echo "$me": "$@"
}

die() {
	msg "$@"
	exit 2
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	cat <<__EOF__
usage:   $me tiers       [Public]
example: $me CentOS
example: $me App,Balancer Public
__EOF__
	exit 1
fi

tiers=$1
public=$2

[ -n "$public" ] && public=Public

[ -n "$WORKSPACE" ] || die "missing env var WORKSPACE"
[ -n "$REPO_CREDENTIALS" ] || die missing env var "REPO_CREDENTIALS=$REPO_CREDENTIALS"

job=$(dirname "$WORKSPACE")
msg jenkins job dir: "$job"
[ -d "$job" ] || die "jenkins job dir not a dir: $job"

config=$job/config.xml
msg jenkins job config: "$config"
[ -f "$config" ] || die "missing config file: $config"

api_user=$(grep userName "$config" | sed -r 's/^[^>]+>//' | sed -r 's/<[^<]+$//')
api_pass=$(grep password "$config" | sed -r 's/^[^>]+>//' | sed -r 's/<[^<]+$//')
cloudRegionId=$(grep cloudType "$config" | sed -r 's/^[^>]+>//' | sed -r 's/<[^<]+$//')
cloudAccountId=$(grep cloudAccount "$config" | sed -r 's/^[^>]+>//' | sed -r 's/<[^<]+$//')

[ -z "$api_user" ] && die "bad api_user"
[ -z "$api_pass" ] && die "bad api_pass"
[ -z "$cloudRegionId" ] && die "bad cloudRegionId"
[ -z "$cloudAccountId" ] && die "bad cloudAccountId"

build_inventory() {
	tier="$1"

	# create ansible inventory file in ansible/hosts:
	msg creating ansible inventory ansible/hosts for tier=[$tier]

	echo "[$tier]" >> ${WORKSPACE}/ansible/hosts

	# scan IPs from Cloud Center tier
	"$WORKSPACE"/cloudcenter/ccc-tier-addresses.sh "$tier" "$public" | while read i; do
		# add ip to ansible inventory
		echo "$i" ansible_ssh_user=cliqruser >> ${WORKSPACE}/ansible/hosts

		# remove ip from known_hosts
		ssh-keygen -R "$i"
	done
}

rm -f ${WORKSPACE}/ansible/hosts
set -- $(echo "$tiers" | sed -e 's/,/ /g')
while [ "$#" -gt 0 ]; do
	build_inventory "$1"
	shift
done

# fetch ssh private key

user=$(id -nu)
msg "user=$user"
if [ "$user" = root ]; then
	apt install -y jq
else
	msg not running as root -- wont apt install jq
fi

curl --silent -u "$api_user:$api_pass" https://cmp.ump.uoldiveo.com/v1/users > "$WORKSPACE/users" || die "failed to download users from cloud center"
userId=$(cat "$WORKSPACE/users" | jq -r ".users[] | select(.username==\"$api_user\") | .id")
echo "$userId" | grep -E '^[0-9]+$' || die "bad userId=$userId for api_user=$api_user"

msg "fetching ssh private key for userId=$userId"

curl --silent -u "$api_user:$api_pass" https://cmp.ump.uoldiveo.com/v1/users/"$userId"/keys > "$WORKSPACE/keys" || die "failed to download key for userId=$userId"
cat "$WORKSPACE/keys" | jq -r ".sshKeys[] | select(.cloudAccountId==\"$cloudAccountId\" and .cloudRegionId==\"$cloudRegionId\") | .key" | sed -e 's/\\n/\n/g' > "$WORKSPACE/keyfile"
grep -e '-----END RSA PRIVATE KEY-----' "$WORKSPACE/keyfile" || die "bad downloaded key for userId=[$userId] cloudAccountId=[$cloudAccountId] cloudRegionId=[$cloudRegionId]"
chmod go-rwx "$WORKSPACE/keyfile"

