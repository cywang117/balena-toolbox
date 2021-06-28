# balena-toolbox
A set of tools acculmulated during time at balena.io


## set-config.sh
Update a config var's value for a device.
```
USAGE:
./set-config.sh DEVICE_UUI BALENA_API_KEY
        -c|--config: Config var to patch in balenaCloud. (Default: BALENA_HOST_EXTLINUX_isolcpus)
        -b|--bool: Specifies whether --config is a true/false config to ensure patch requests are accurate. (Default: false)
```
