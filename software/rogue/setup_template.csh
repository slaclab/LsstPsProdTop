# Setup environment
source /afs/slac/g/reseng/rogue/master/setup_env.csh

# Package directories
setenv SURF_DIR   ${PWD}/../../firmware/submodules/surf/python
setenv CORE_DIR  ${PWD}/../../firmware/submodules/lsst-pwr-ctrl-core/python

# Setup python path
setenv PYTHONPATH ${PWD}/python:${SURF_DIR}:${CORE_DIR}:${PYTHONPATH}
