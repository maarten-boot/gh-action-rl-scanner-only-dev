#! /usr/bin/env bash

prep_report()
{
    if [ -z "${{ inputs.report-path }}" ]
    then
      echo "FATAL: no report path provided" >&2
      exit 101
    fi

    rm -rf "${{ inputs.report-path }}"
    mkdir -p "${{ inputs.report-path }}"
}

prep_paths()
{
    R_PATH=$( realpath "${{ inputs.report-path }}" )
    A_PATH=$( realpath "${{ inputs.artifact-to-scan }}" )
    A_DIR=$( dirname "${A_PATH}" )
    A_FILE=$( basename "${A_PATH}" )
}

scan_no_store()
{
    # docker pull reversinglabs/rl-scanner:latest
    docker run --rm -u $(id -u):$(id -g) \
      -e "RLSECURE_ENCODED_LICENSE=${{ env.RLSECURE_ENCODED_LICENSE }}" \
      -e "RLSECURE_SITE_KEY=${{ env.RLSECURE_SITE_KEY }}" \
      -v "${A_DIR}/:/packages:ro" \
      -v "${R_PATH}/:/report" \
      reversinglabs/rl-scanner:latest \
        rl-scan --package-path="/packages/${A_FILE}" \
          --report-path=/report \
          --report-format=all
}

main()
{
    prep_report
    prep_paths
    scan_no_store
}

main $@
