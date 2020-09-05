#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This script is used to import any configurations that are
#- needed after PingAccess starts

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE" || test "${OPERATIONAL_MODE}" = "STANDALONE"
then
    #cp /opt/out/instance/server/default/conf/data-default.zip /opt/out/instance/server/default/data/drop-in-deployer/data.zip
    echo "INFO: 4 waiting for PingFederate to start before importing configuration"
    wait-for localhost:9999 -t 200 -- echo PingFederate is up
    curl -X PUT --header 'Content-Type: application/json' --header 'X-XSRF-Header: PingFederate' --data '@/opt/staging/hooks/licenseagree.json' https://localhost:9999/pf-admin-api/v1/license/agreement --insecure
    curl -X POST --header 'Content-Type: application/json' --header 'X-XSRF-Header: PingFederate' --data '@/opt/staging/hooks/createadmin.json' https://localhost:9999/pf-admin-api/v1/administrativeAccounts --insecure
    curl -X POST --basic -u Administrator:2FederateM0re --header 'Content-Type: application/json' --header 'X-XSRF-Header: PingFederate' --header 'X-BypassExternalValidation: true' --data '@/opt/out/instance/bulkconfig.json' https://localhost:9999/pf-admin-api/v1/bulk/import?failFast=false --insecure
    test ${?} -ne 0 && kill 1
fi

if test "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"
then
    echo "INFO: Configuring engine node"
    echo "Downloading data.zip from the PF Console."

    # PF Engines are supposed to download config from the console over jgroups, but this approach may be more robust
    # We need to find a better way to distribute the data.zip without requiring admin credentials
    curl -X GET --basic -u Administrator:2FederateM0re --header 'Content-Type: application/zip' --header 'X-XSRF-Header: PingFederate' https://pingfederate-admin:9999/pf-admin-api/v1/configArchive/export  -L -o data.zip --insecure
    unzip -o -d /opt/out/instance/server/default/data data.zip
fi

if test "${OPERATIONAL_MODE}" = "CLUSTERED_CONSOLE"
then
    echo "Bringing eth0 back up..."
    ip link set eth0 up
fi
