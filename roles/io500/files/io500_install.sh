#!/bin/bash
# Installs IO500

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
DEFAULT_IO500_ENV_FILE="${SCRIPT_DIR}/io500.env"

: "${DAOS_IO500_ENV_FILE:="${DEFAULT_IO500_ENV_FILE}"}"
: "${DAOS_IO500_VERSION:="io500-sc23"}"
: "${DAOS_IO500_INSTALL_DIR:="/opt/${DAOS_IO500_VERSION}"}"

# BEGIN: Logging
: "${DAOS_AZ_LOG_LEVEL:="INFO"}"
: "${LOG_COLS:="80"}"
: "${LOG_LINE_CHAR:="-"}"

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15)

log() {
  local msg="$1"
  local lvl=${2:-INFO}
  if [[ ${LOG_LEVELS[$DAOS_AZ_LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${LOG_COLORS[$lvl]}"; fi
    printf "[%-5s] %s\n" "$lvl" "${msg}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.debug() { log "${1}" "DEBUG"; }
log.info() { log "${1}" "INFO"; }
log.warn() { log "${1}" "WARN"; }
log.error() { log "${1}" "ERROR"; }
log.fatal() { log "${1}" "FATAL"; }
log.debug.vars() {
  local var_prefix="${1:-"DAOS_"}"
  local daos_vars

  if [[ "${DAOS_AZ_LOG_LEVEL}" == "DEBUG" ]]; then
    log.debug && log.debug "ENVIRONMENT VARIABLES" && log.debug "---"
    readarray -t daos_vars < <(compgen -A variable | grep "${var_prefix}" | sort)
    for item in "${daos_vars[@]}"; do
      log.debug "${item}=${!item}"
    done
    echo
  fi
}

log.line() {
  local line_char="${1:-$LOG_LINE_CHAR}"
  local line_width="${2:-$LOG_COLS}"
  local fg_color="${3:-${LOG_COLORS['OTHER']}}"
  local line
  line=$(printf "%${line_width}s" | tr " " "${line_char}")
  if [[ ${LOG_LEVELS[${DAOS_AZ_LOG_LEVEL}]} -le ${LOG_LEVELS[OFF]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${fg_color}"; fi
    printf -- "%s\n" "${line}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.section() {
  # log.section msg [line_width] [line_char] [fg_color]
  local msg="${1:-}"
  local line_width="${2:-$LOG_COLS}"
  local line_char="${3:-$LOG_LINE_CHAR}"
  local fg_color="${4:-${LOG_COLORS['OTHER']}}"
  if [[ ${LOG_LEVELS[${DAOS_AZ_LOG_LEVEL}]} -le ${LOG_LEVELS[OFF]} ]]; then
    log.line "${line_char}" "${line_width}" "${fg_color}"
    if [[ -t 1 ]]; then tput setaf "${fg_color}"; fi
    echo -e "${msg}" 1>&2
    log.line "${line_char}" "${line_width}" "${fg_color}"
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}
# END: Logging

env_load() {
  log
  local env_file="${1}"
  if [[ -n "${env_file}" ]]; then
    if [[ -f "${env_file}" ]]; then
      log.debug "Sourcing ${env_file}"
      # shellcheck disable=SC2163,SC1090
      source "${env_file}"
    else
      log.error "File not found: ${env_file}"
      exit 1
    fi
  fi
}

env_export() {
  local var_prefix="$1"
  readarray -t daos_vars < <(compgen -A variable | grep "${var_prefix}" | sort)
  for var in "${daos_vars[@]}"; do
    # shellcheck disable=SC2163
    export "$var"
  done
}

install_dependencies() {
  dnf -y install epel-release
  dnf -y group install "Development Tools"
  dnf -y install bzip2-devel clustershell daos-devel gcc-toolset-9-gcc \
    gcc-toolset-9-gcc-c++ git jq libarchive-devel libuuid-devel lsof \
    nvme-cli openssl-devel patch pciutils pdsh rsync sudo vim wget which
}

clone_io500_repo() {
if [[ ! -d "${DAOS_IO500_INSTALL_DIR}" ]]; then
  mkdir -p "${DAOS_IO500_INSTALL_DIR}"
  git clone --depth 1 --branch "${DAOS_IO500_VERSION}" https://github.com/IO500/io500.git "${DAOS_IO500_INSTALL_DIR}"
fi
}

modify_io500_files() {
  cd "${DAOS_IO500_INSTALL_DIR}"
  log.info "Modifying ${DAOS_IO500_INSTALL_DIR}/prepare.sh"
  git checkout prepare.sh # For idempotency
  sed -i 's|PFIND_HASH=.*|PFIND_HASH=dfs_find|g' prepare.sh
  sed -i "s|git_co https://github.com/VI4IO/pfind.git pfind \$PFIND_HASH|git_co ${DAOS_IO500_PFIND_GIT_REPO} pfind \$PFIND_HASH|g" prepare.sh
  sed -i "s|./configure --prefix=.*|./configure --prefix=\"\$INSTALL_DIR\" --with-daos=\"${DAOS_IO500_INSTALL_DIR}\"|g" prepare.sh

  log.info "Modifying ${DAOS_IO500_INSTALL_DIR}/${makefile}"
  git checkout Makefile # For idempotency
  sed -i "/CFLAGS += -std=gnu99 .*/a\CFLAGS += -I\${DAOS_IO500_INSTALL_DIR}/include" Makefile
  sed -i "/LDFLAGS += -lm.*/a\LDFLAGS += -L\${DAOS_IO500_INSTALL_DIR}/lib64 -ldaos -ldaos_common -ldfs -lgurt -luuid" Makefile
}

run_prepare() {
  export I_MPI_OFI_LIBRARY_INTERNAL=0
  export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"
  export FI_UNIVERSE_SIZE=16383
  export FI_OFI_RXM_USE_SRX=1
  source /opt/intel/oneapi/setvars.sh
  export PATH=$PATH:"${DAOS_IO500_INSTALL_DIR}/bin"
  cd "${DAOS_IO500_INSTALL_DIR}"
  ./prepare.sh
}

main() {
  env_load "${DAOS_IO500_ENV_FILE}"
  install_dependencies
  clone_io500_repo
  modify_io500_files
  run_prepare
}

main
