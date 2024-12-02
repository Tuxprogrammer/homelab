#!/usr/bin/env bash

set -o nounset
set -o errexit

apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
apt-get install -y apt-transport-https ca-certificates curl gnupg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

apt-get update
apt-get install -y kubectl

current_ipv4="$(curl -s https://ipv4.icanhazip.com/)"
zone_id=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones?name=${CLOUDFLARE_RECORD_NAME#*.}&status=active" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_APIKEY}" \
    -H "Content-Type: application/json" \
        | jq --raw-output ".result[0] | .id"
)
record_ipv4=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${CLOUDFLARE_RECORD_NAME}&type=A" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_APIKEY}" \
    -H "Content-Type: application/json" \
)
old_ip4=$(echo "$record_ipv4" | jq --raw-output '.result[0] | .content')
if [[ "${current_ipv4}" == "${old_ip4}" ]]; then
    printf "%s - IP Address '%s' has not changed" "$(date -u)" "${current_ipv4}"
    exit 0
fi
record_ipv4_identifier="$(echo "$record_ipv4" | jq --raw-output '.result[0] | .id')"
update_ipv4=$(curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_ipv4_identifier}" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "X-Auth-Key: ${CLOUDFLARE_APIKEY}" \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"${zone_id}\",\"type\":\"A\",\"proxied\":true,\"name\":\"${CLOUDFLARE_RECORD_NAME}\",\"content\":\"${current_ipv4}\"}" \
)
if [[ "$(echo "$update_ipv4" | jq --raw-output '.success')" == "true" ]]; then
    printf "%s - Success - IP Address '%s' has been updated" "$(date -u)" "${current_ipv4}"
    exit 0
else
    printf "%s - Yikes - Updating IP Address '%s' has failed" "$(date -u)" "${current_ipv4}"
    exit 1
fi
