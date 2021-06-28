#!/bin/bash

set -o errexit

USAGE=$(cat <<-END
    USAGE:
        \n./set-config.sh DEVICE_UUID BALENA_API_KEY
        \n\t-c|--config: \tConfig var to patch in balenaCloud. (Default: BALENA_HOST_EXTLINUX_isolcpus)
        \n\t-b|--bool: \tSpecifies whether --config is a true/false config to ensure patch requests are accurate. (Default: false)
    \nExamples:
    \n\t./set-config.sh 1234567 myApiToken --config=RESIN_HOST_CONFIG_enable_uart -b
END
)

DEVICE_UUID=$1
BALENA_API_KEY=$2
CONFIG=BALENA_HOST_EXTLINUX_isolcpus
ISBOOL=false

# Get flag opts (https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash)
for i in "$@"; do
    case $i in
        -c=*|--config=*)
            CONFIG="${i#*=}"
            shift
            ;;
        -b|--bool)
            ISBOOL=true
            shift
            ;;
        *)
            ;;
    esac
done

# Validate required command line arguments
if [[ -z "$DEVICE_UUID" || -z "$BALENA_API_KEY" ]]; then
    echo -e '\nDEVICE_UUID and BALENA_API_KEY are required arguments.\n'
    echo -e $USAGE
    exit 1;
fi

if [[ "${#DEVICE_UUID}" -ne 32 && "${#DEVICE_UUID}" -ne 7 ]]; then
    echo -e "\nDEVICE_UUID must have length 32 (full uuid) or 7 (short uuid)."
    echo -e $USAGE
    exit 1;
fi;

echo "Updating config $CONFIG for $DEVICE_UUID..."

# Get device id (unique database ID in backend) based on $DEVICE_UUID
DEVICE_ID=$(
    curl "https://api.balena-cloud.com/v6/device?\$filter=startswith(uuid,'$DEVICE_UUID')&\$select=id" \
        -X GET --compressed --silent \
        -H 'Accept: */*' \
        -H "authorization: Bearer $BALENA_API_KEY" \
        -H 'content-type: application/json' | jq '.d[0].id'
)

# Get config id & val of $CONFIG (database values)
read CONFIG_ID CONFIG_VAL < <(echo $(
    curl "https://api.balena-cloud.com/v6/device_config_variable?\$orderby=name%20asc&\$filter=device%20eq%20$DEVICE_ID%20and%20name%20eq%20'$CONFIG'" \
    -X GET --compressed --silent \
     -H 'Accept: */*' \
     -H "authorization: Bearer $BALENA_API_KEY" \
     -H 'content-type: application/json' | jq -r '.d[0].id, .d[0].value'
))

# Exit if CONFIG_ID or CONFIG_VAL are empty
if [[ $CONFIG_ID == null || $CONFIG_VAL == null ]]; then 
    echo -e "Cannot find $CONFIG for $DEVICE_UUID. Is this config valid for your device type?"
    exit 1;
fi

# Target value must be 0 or 1 for true/false type configs
if [[ $ISBOOL == true ]]; then
    TARGET_VAL=$([ "$CONFIG_VAL" = 1 ] && echo "0" || echo "1" )
else
    TARGET_VAL=$([ "$CONFIG_VAL" = 2 ] && echo "1" || echo "2" )
fi
echo "Current $CONFIG is $CONFIG_VAL, setting to $TARGET_VAL..."

# Patch config
curl "https://api.balena-cloud.com/v6/device_config_variable($CONFIG_ID)" -X PATCH \
    -H 'Accept: */*' -H "authorization: Bearer $BALENA_API_KEY" \
    -H 'content-type: application/json' \
    --compressed --silent --data-raw "{\"value\":\"$TARGET_VAL\"}"

exit 0;
