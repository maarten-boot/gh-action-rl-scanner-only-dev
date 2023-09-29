#! /bin/bash

do_verbose()
{
    cat <<!
REPORT_PATH:              ${REPORT_PATH}
MY_ARTIFACT_TO_SCAN_PATH: ${MY_ARTIFACT_TO_SCAN_PATH}
RL_STORE:                 ${RL_STORE}
RL_PACKAGE_URL:           ${RL_PACKAGE_URL}
RL_DIFF_WITH:             ${RL_DIFF_WITH}
RL_VERBOSE:               ${RL_VERBOSE}
!
}

prep_report()
{
    if [ -z "${REPORT_PATH}" ]
    then
        echo "FATAL: no report path provided" >&2
    exit 101
    fi

    rm -rf "${REPORT_PATH}"
    mkdir -p "${REPORT_PATH}"
}

prep_paths()
{
    R_PATH=$( realpath "${REPORT_PATH}" )
    A_PATH=$( realpath "${MY_ARTIFACT_TO_SCAN_PATH}" )
    A_DIR=$( dirname "${A_PATH}" )
    A_FILE=$( basename "${A_PATH}" )
}

scan_no_store()
{
    docker run --rm -u $(id -u):$(id -g) \
    -e "RLSECURE_ENCODED_LICENSE=${RLSECURE_ENCODED_LICENSE}" \
    -e "RLSECURE_SITE_KEY=${RLSECURE_SITE_KEY}" \
    -v "${A_DIR}/:/packages:ro" \
    -v "${R_PATH}/:/report" \
    reversinglabs/rl-scanner:latest \
        rl-scan --package-path="/packages/${A_FILE}" \
            --report-path=/report \
            --report-format=all}
}

main()
{
    do_verbose
    prep_report
    prep_paths
    scan_no_store
}

main $@
