#!/usr/bin/env bash
set -x

# Set location of this script as current directory.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"
cd "${DIR}"

if [ ! -z "${1}" ] || [ ! -z "${2}" ]
then
   INPUTDIR=$1
   OUTPUTDIR=$2
else
    echo "Error: no inputdir or outputdir given."
    exit 1
fi

if [ ! -d "${INPUTDIR}" ] || [ ! -d "${OUTPUTDIR}" ]
then
    echo "Error: inputdir $INPUTDIR or output dir $OUTPUTDIR not exists"
    exit 2
fi

echo Before environment creation

# Setup environment
mamba env update -f envs/mlva_env.conda.yml -q
set +x
source activate mlva_env
set -x

echo After environment creation

# Execute mlva (test) script
bash src/get_mlva_profile_for_iRODS.sh "${INPUTDIR}" "${OUTPUTDIR}"

echo After running get_mlva script
