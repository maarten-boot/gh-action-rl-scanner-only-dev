#! /bin/bash


do_verbose()
{
    if [ "${RL_VERBOSE}" == "false" ]
    then
        return
    fi

    cat <<!
REPORT_PATH:              ${REPORT_PATH:-No path specified}
MY_ARTIFACT_TO_SCAN_PATH: ${MY_ARTIFACT_TO_SCAN_PATH:-No path specified}

RL_STORE:                 ${RL_STORE:-No path specified for RL_STORE: no diff scan can be executed}
RL_PACKAGE_URL:           ${RL_PACKAGE_URL:-No Package Url given: no diff scan can be executed}
RL_DIFF_WITH:             ${RL_DIFF_WITH:-No diff with was requested}

RLSECURE_PROXY_SERVER:    ${RLSECURE_PROXY_SERVER:-No proxy server was provided}
RLSECURE_PROXY_PORT:      ${RLSECURE_PROXY_PORT:-No proxy port was provided}
RLSECURE_PROXY_USER:      ${RLSECURE_PROXY_USER:-No proxy user was provided}
RLSECURE_PROXY_PASSWORD:  ${RLSECURE_PROXY_PASSWORD:-No proxy pass was provided}
!
}

prep_report()
{
    if [ -z "${REPORT_PATH}" ]
    then
        echo "::error FATAL: no report path provided"
        exit 101
    fi

    if [ -d "${REPORT_PATH}" ]
    then
        if rmdir "${REPORT_PATH}"
        then
            :
        else
            echo "::error FATAL: your current REPORT_PATH is not empty"
            exit 101
        fi
    fi

    mkdir -p "${REPORT_PATH}"
}

prep_paths()
{
    R_PATH=$( realpath "${REPORT_PATH}" )

    A_PATH=$( realpath "${MY_ARTIFACT_TO_SCAN_PATH}" )
    A_DIR=$( dirname "${A_PATH}" )
    A_FILE=$( basename "${A_PATH}" )
}

extractProjectFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[0]          # print Project
    }'
}

extractPackageFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[1]          # print Package
    }'
}

makeDiffWith()
{
    DIFF_WITH=""

    if [ -z "$RL_STORE" ]
    then
        return
    fi

    if [ -z "${RL_PACKAGE_URL}" ]
    then
        return
    fi

    if [ -z "${RL_DIFF_WITH}" ]
    then
        return
    fi

    # Split the package URL and find Project and Package
    Project=$( extractProjectFromPackageUrl )
    Package=$( extractPackageFromPackageUrl )

    if [ ! -d "$RL_STORE/.rl-secure/projects/${Project}/packages/${Package}/versions/${RL_DIFF_WITH}" ]
    then
        echo "That version has not been scanned yet: ${RL_DIFF_WITH}"
        return
    fi

    DIFF_WITH="--diff-with=${RL_DIFF_WITH}"
}

do_proxy_data()
{
    PROXY_DATA=""

    if [ ! -z "${RLSECURE_PROXY_SERVER}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_SERVER=${RLSECURE_PROXY_SERVER}"
    fi

    if [ ! -z "${RLSECURE_PROXY_PORT}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PORT=${RLSECURE_PROXY_PORT}"
    fi

    if [ ! -z "${RLSECURE_PROXY_USER}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_USER=${RLSECURE_PROXY_USER}"
    fi

    if [ ! -z "${RLSECURE_PROXY_PASSWORD}" ]
    then
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PASSWORD=${RLSECURE_PROXY_PASSWORD}"
    fi
}

scan_with_store()
{
    docker run --rm -u $(id -u):$(id -g) \
    -e "RLSECURE_ENCODED_LICENSE=${RLSECURE_ENCODED_LICENSE}" \
    -e "RLSECURE_SITE_KEY=${RLSECURE_SITE_KEY}" \
    ${PROXY_DATA} \
    -v "${A_DIR}/:/packages:ro" \
    -v "${R_PATH}/:/report" \
    reversinglabs/rl-scanner:latest \
        rl-scan --package-path="/packages/${A_FILE}" \
            --rl-store=${RL_STORE} \
            --package-path=${RL_PACKAGE_URL} \
            --replace \
            --report-path=/report \
            --report-format=all \
            ${DIFF_WITH}
}

scan_no_store()
{
    docker run --rm -u $(id -u):$(id -g) \
    -e "RLSECURE_ENCODED_LICENSE=${RLSECURE_ENCODED_LICENSE}" \
    -e "RLSECURE_SITE_KEY=${RLSECURE_SITE_KEY}" \
    ${PROXY_DATA} \
    -v "${A_DIR}/:/packages:ro" \
    -v "${R_PATH}/:/report" \
    reversinglabs/rl-scanner:latest \
        rl-scan --package-path="/packages/${A_FILE}" \
            --report-path=/report \
            --report-format=all
}

what_scan_type()
{
    if [ -z "${RL_STORE}" ]
    then
        return 0
    fi

    if [ -z "${RL_PACKAGE_URL}" ]
    then
        return 0
    fi

    return 1
}

main()
{
    do_verbose

    prep_report
    prep_paths
    makeDiffWith
    do_proxy_data

    if [ what_scan_type == "0" ]
    then
        scan_no_store
    else
        scan_with_store
    fi
}

main $@
