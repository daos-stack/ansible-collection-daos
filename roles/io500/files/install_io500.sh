#!/bin/bash

set -eo pipefail

# This is to test instructions on the wiki
# https://daosio.atlassian.net/wiki/spaces/DC/pages/11167301633/IO-500+SC22

# When DAOS is installed with RPMs MY_DAOS_INSTALL_PATH=/usr/lib
MY_DAOS_INSTALL_DIR="/usr/lib64"
MY_IO500_VERSION="io500-sc23"
MY_IO500_DIR="/opt/${MY_IO500_VERSION}"
MY_IO500_RESULT_DIR="${HOME}/${MY_IO500_VERSION}_results"
MY_IO500_CONFIG_INI_FILE_NAME="config-full-isc22.ini"
MY_IO500_CONFIG_INI_FILE_URL="https://raw.githubusercontent.com/mchaarawi/io500/ini_files/${MY_IO500_CONFIG_INI_FILE_NAME}"

if [[ ! -d "${MY_IO500_DIR}" ]]; then
  mkdir -p "${MY_IO500_DIR}" "${MY_IO500_RESULT_DIR}"
  git clone --depth 1 --branch "${MY_IO500_VERSION}" https://github.com/IO500/io500.git "${MY_IO500_DIR}"
fi

cd "${MY_IO500_DIR}"
git checkout prepare.sh
sed -i 's|PFIND_HASH=.*|PFIND_HASH=dfs_find|g' "${MY_IO500_DIR}/prepare.sh"
sed -i 's|git_co https://github.com/VI4IO/pfind.git pfind $PFIND_HASH|git_co https://github.com/mchaarawi/pfind.git pfind $PFIND_HASH|g' "${MY_IO500_DIR}/prepare.sh"
sed -i "s|./configure --prefix=.*|./configure --prefix=\"\$INSTALL_DIR\" --with-daos=\"${MY_DAOS_INSTALL_DIR}\"|g" "${MY_IO500_DIR}/prepare.sh"

git checkout Makefile
sed -i "/CFLAGS += -std=gnu99 .*/a\CFLAGS += -I\${MY_DAOS_INSTALL_PATH}/include" Makefile
sed -i "/LDFLAGS += -lm.*/a\LDFLAGS += -L\${MY_DAOS_INSTALL_PATH}/lib64 -ldaos -ldaos_common -ldfs -lgurt -luuid" Makefile

export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"
export PATH=$PATH:"${DAOS_IO500_DIR}/bin"
export FI_UNIVERSE_SIZE=16383
export FI_OFI_RXM_USE_SRX=1
source /opt/intel/oneapi/setvars.sh
./prepare.sh

if [[ ! -f "${MY_IO500_CONFIG_INI_FILE_NAME}" ]]; then
  wget "${MY_IO500_CONFIG_INI_FILE_URL}"
fi
