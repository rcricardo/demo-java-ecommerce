#!/bin/bash

me=$(basename "$0")

msg() {
      echo >&2 "$me": "$@"
}

die() {
      msg "$@"
      exit 1
}

if [ "$#" -ne 4 ]; then
	cat >&2 <<__EOF__
usage:   $me tier1      tier2      zone_id       fqdn
example: $me Balancer_1 Balancer_2 ZI3C1STC6IPR3 dev-ecommerce.demo.z1.orbx.uoldiveo.com
__EOF__
	exit 2
fi

tier1="$1"
tier2="$2"
zone_id="$3"
fqdn="$4"

[ -n "$WORKSPACE" ] || die missing env var "WORKSPACE=$WORKSPACE"
[ -r "$WORKSPACE"/userenv ] || die missing userenv: "$WORKSPACE"/userenv

ip1=$(grep "CliqrTier_${tier1}_PublicIP" "$WORKSPACE"/userenv | awk -F= '{ print $2 }')
ip2=$(grep "CliqrTier_${tier2}_PublicIP" "$WORKSPACE"/userenv | awk -F= '{ print $2 }')

[ -n "$ip1" ] || die missing ip1 from userenv tier1="$tier1"
[ -n "$ip2" ] || die missing ip2 from userenv tier2="$tier2"

default_ttl=30
[ -z "$TTL" ] && TTL=$default_ttl
msg using DNS TTL=$TTL -- default was TTL=$default_ttl

issue_rrs() {

	local hc="$1"
	local ip="$2"
	local id="$3"

cat <<__EOF__
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "HealthCheckId": "$hc",
        "Name": "${fqdn}.",
        "Weight": 1,
        "Type": "A",
        "ResourceRecords": [
          {
            "Value": "$ip"
          }
        ],
        "TTL": $TTL,
        "SetIdentifier": "$id"
      }
    }
__EOF__

}

issue_changes() {

cat <<__EOF__
{
  "Changes": [
__EOF__

issue_rrs "$healthcheck1" "$ip1" "$id1"
echo ,
issue_rrs "$healthcheck2" "$ip2" "$id2"

cat <<__EOF__
  ]
}
__EOF__

}

aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" > "$WORKSPACE"/zone || die "could not fetch zone: $zone_id"

id1="${fqdn}"-1
id2="${fqdn}"-2

# get health check id
healthcheck1=$(jq ".ResourceRecordSets[] | select(.SetIdentifier == \"$id1\") | .HealthCheckId" < "$WORKSPACE"/zone | sed -e 's/"//g')
healthcheck2=$(jq ".ResourceRecordSets[] | select(.SetIdentifier == \"$id2\") | .HealthCheckId" < "$WORKSPACE"/zone | sed -e 's/"//g')

[ -n "$healthcheck1" ] || die could not get healthcheck_id for SetIdentifier="$id1"
[ -n "$healthcheck2" ] || die could not get healthcheck_id for SetIdentifier="$id2"

# update zone
batch=$(issue_changes)
aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "$batch"

# update health check
aws route53 update-health-check --health-check-id "$healthcheck1" --ip-address "$ip1"
aws route53 update-health-check --health-check-id "$healthcheck2" --ip-address "$ip2"

echo done: http://"${fqdn}"/


