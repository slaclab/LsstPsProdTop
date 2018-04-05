# Setup environment
source /afs/slac/g/reseng/rogue/v2.8.0/setup_env.sh
#source /afs/slac/g/reseng/rogue/master/setup_env.sh
#source /afs/slac/g/reseng/rogue/pre-release/setup_env.sh

# Submodule Python Package directories
export SURF_DIR=${PWD}/../../firmware/submodules/surf/python
export CORE_DIR=${PWD}/../../firmware/submodules/lsst-pwr-ctrl-core/python

# Setup python path
export PYTHONPATH=${PWD}/python:${SURF_DIR}:${CORE_DIR}:${PYTHONPATH}
