#! /bin/bash
# Wrapper to run yapf-diff for repo preupload.
# Usage: if the first argument is --bypass, do nothing (exit 0). If the first
# argument is a git hash, run yapf-diff on that commit, otherwise run yapf-diff
# on the last commit. Any other arguments are passed to yapf-diff.
# The script fails if yapf-diff produces any output.

COMMIT="$(git log --format='%H' -1)"

if [ $# -gt 0 ] ; then
    if [ "$1" == "--bypass" ] ; then
        exit 0
    fi

    if [[ ! "$1" =~ ^- ]] ; then
        COMMIT="$1"
        shift
    fi
fi

if git show -U0 --no-color "${COMMIT}" | yapf-diff "$@" | grep --color=never . ; then
    cat <<EOF


Please fix the formatting issues above before uploading.
You can apply the changes above by running:
$0 $COMMIT -i
EOF
    exit 1
fi
