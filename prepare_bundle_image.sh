#! /bin/bash

# Script for preparing a cpio archive of builtin applications and/or models.
# Usage: prepare_bundle_image [-n] -o target.cpio
#                   [-m input_model...] [-a input_app...]
# where
#   -o target cpio archive filena,me
#   -m identifies subsequent arguments as models
#   -a identifies subsequent arguments as applications
# also
#   -n do a dry-run where commands are just echo'd to the terminal

# TODO(sleffler): redo with getopt

if [[ -z "${ROOTDIR}" ]]; then
    echo "No ROOTDIR, source build/setup.sh first"
    exit 1
fi
if [[ -z "${KATA_RUST_VERSION}" ]]; then
    echo "No KATA_RUST_VERSION, source build/setup.sh first"
    exit 1
fi
if [[ -z "${CARGO_HOME}" ]]; then
    echo "No CARGO_HOME, source build/setup.sh first"
    exit 1
fi

TMP_DIR="${OUT}/tmp"
if [[ ! -d "${TMP_DIR}" ]]; then
    echo "No tmp directory found at ${TMP_DIR}"
    exit 2
fi

CARGO="${CARGO_HOME}/bin/cargo +${KATA_RUST_VERSION}"
CPIO_OPTS='-H newc -L --no-absolute-filenames --reproducible --owner=root:root'

function prepare_bundle_image {
    cd "${ROOTDIR}/kata/tools/seL4/misc/prepare_bundle_image" && \
        ${CARGO} run -q  --target-dir "${OUT}/host/prepare_bundle_image" -- "$@"
}

dry_run='false'
if [[ "$1" == '-n' ]]; then
    dry_run='true'
    shift
fi
if [[ "$1" != '-o' ]]; then
    echo "Missing -o option to specify output cpio archive"
    exit 3
fi
OUTPUT_CPIO="$2"
shift 2

APPS='-a'
MODELS='-m'
file_type=
for arg; do
    case "${arg}" in
    -a) file_type='app';;
    -m) file_type='model';;
     *) case "${file_type}" in
        app)
            ln -sf "${arg}" "${TMP_DIR}" && \
                APPS="${APPS} ${TMP_DIR}/$(basename ${arg})"
            ;;
        model)
            ln -sf "${arg}" "${TMP_DIR}" && \
                MODELS="${MODELS} ${TMP_DIR}/$(basename ${arg})"
            ;;
        *) echo 'Missing -m or -a option to identify file type'; exit -1;;
        esac
    esac
done

if [[ "${dry_run}" == 'true' ]]; then
    # TODO(sleffler): would be nice to print what prepare_bundle_image would do
    echo "prepare_bundle_image ${MODELS} ${APPS} | cpio -o -D ${TMP_DIR} ${CPIO_OPTS} -O ${OUTPUT_CPIO}"
else
    prepare_bundle_image ${MODELS} ${APPS} | cpio -o -D ${TMP_DIR} ${CPIO_OPTS} -O "${OUTPUT_CPIO}"
fi
