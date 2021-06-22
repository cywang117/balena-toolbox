#!/bin/bash

set -o errexit

if [[ $# -lt 2 ]]; then
    echo USAGE: set-host-config.sh DEVICE_UUID BALENA_API_KEY [CONFIG_VAR = BALENA_HOST_EXTLINUX_isolcpus]
    exit 1;
fi

uuid=$1
token=$2
config_to_set=$([ $3 ] && echo $3 || echo BALENA_HOST_EXTLINUX_isolcpus)

echo "Updating boot config $config_to_set for device $uuid..."

# Get device id based on device uuid
device_id=$(curl "https://api.balena-cloud.com/v6/device?\$filter=startswith(uuid,'$uuid')&\$select=id" -X GET -H 'Accept: */*' --compressed --silent -H "authorization: Bearer $token" -H 'content-type: application/json' | jq '.d[0].id')

# Get config id & val of $config_to_set
read config_id config_val < <(echo $(curl "https://api.balena-cloud.com/v6/device_config_variable?\$orderby=name%20asc&\$filter=device%20eq%20$device_id%20and%20name%20eq%20'$config_to_set'" -X GET -H 'Accept: */*' --compressed --silent -H "authorization: Bearer $token" -H 'content-type: application/json' | jq -r '.d[0].id, .d[0].value'))

# Exit if config_id or config_val are empty
if [[ $config_id == null || $config_val == null ]]; then 
    echo "Cannot find $config_to_set for device $uuid, exiting."
    exit 1;
fi

# TODO: Target values don't work for all host configs, works for BALENA_HOST_EXTLINUX_isolcpus at least
target_val=$([ "$config_val" = 2 ] && echo "1" || echo "2" )
echo "Current $config_to_set is $config_val, setting to $target_val..."

curl "https://api.balena-cloud.com/v6/device_config_variable($config_id)" -X PATCH \
    -H 'Accept: */*' -H "authorization: Bearer $token" \
    -H 'content-type: application/json' \
    --compressed --silent --data-raw "{\"value\":\"$target_val\"}"

echo -e "Value patched, exiting."
exit 0;
