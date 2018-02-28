# Setup environment
source /afs/slac/g/reseng/rogue/master/setup_env.sh

# Submodule Python Package directories
export SURF_DIR=${PWD}/../../firmware/submodules/surf/python
export CORE_DIR=${PWD}/../../firmware/submodules/lsst-pwr-ctrl-core/python

# Setup python path
export PYTHONPATH=${PWD}/python:${SURF_DIR}:${CORE_DIR}:${PYTHONPATH}
