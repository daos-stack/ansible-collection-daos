#!/usr/bin/env bash
# Copyright 2023 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Run IO500 benchmark for DAOS
#

set -eo pipefail
trap 'echo "An error occurred. Exiting."; unmount' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
SCRIPT_FILE=$(basename "${BASH_SOURCE[0]}")
TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
RUN_ID=$(uuidgen | tr 'a-f' 'A-F')

exec 3>&1
exec > >(tee ${SCRIPT_DIR}/${SCRIPT_FILE%.*}.${TIMESTAMP}.log) 2>&1

DEFAULT_ENV_FILE="${SCRIPT_DIR}/io500.env"

: "${DAOS_IO500_ENV_FILE:="${DEFAULT_ENV_FILE}"}"
: "${DAOS_SERVER_HOSTS_FILE:="${SCRIPT_DIR}/hosts_servers"}"
: "${DAOS_CLIENT_HOSTS_FILE:="${SCRIPT_DIR}/hosts_clients"}"

# : "${DAOS_IO500_DFUSE_DIR:="${HOME}/dfuse/${DAOS_IO500_VERSION_TAG}"}"
# : "${DAOS_IO500_DFUSE_DATA_DIR:="${DAOS_IO500_DFUSE_DIR}/datafiles"}"
# : "${DAOS_IO500_RESULTS_DIR:="${HOME}/${DAOS_IO500_VERSION_TAG}/results"}"

# : "${DAOS_IO500_INI:="${HOME}/io500_ini/io500-sc23.config.ini.envtpl"}"
# : "${DAOS_IO500_STONEWALL_TIME:=30}"
# : "${DAOS_POOL:="io500_pool"}"
# : "${DAOS_CONT:="io500_cont"}"
# : "${DAOS_CONT_REPLICATION_FACTOR:="rf:0"}"
# : "${DAOS_CHUNK_SIZE:=1048576}"

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
    log.debug && log.debug "----- ENVIRONMENT VARIABLES -----"
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

verify() {
  local exit_code=0

  if [[ ! -f "${DAOS_IO500_ENV_FILE}" ]]; then
    log.error "DAOS_IO500_ENV_FILE=${DAOS_IO500_ENV_FILE}"
    log.error "File not found: ${DAOS_IO500_ENV_FILE}"
    exit_code=1
  fi

  if [[ ! -f "${DAOS_SERVER_HOSTS_FILE}" ]]; then
    log.error "DAOS_SERVER_HOSTS_FILE=${DAOS_SERVER_HOSTS_FILE}"
    log.error "File not found: ${DAOS_SERVER_HOSTS_FILE}"
    exit_code=1
  fi

  if [[ ! -f "${DAOS_CLIENT_HOSTS_FILE}" ]]; then
    log.error "DAOS_CLIENT_HOSTS_FILE=${DAOS_CLIENT_HOSTS_FILE}"
    log.error "File not found: ${DAOS_CLIENT_HOSTS_FILE}"
    exit_code=1
  fi

  if [[ $exit_code -ne 0 ]]; then
    log.error "Exiting ... "
    exit $exit_code
  fi
}

env_export() {
  local env_prefix="${1:-"DAOS_"}"
  readarray -t daos_vars < <(compgen -A variable | grep "DAOS_" | sort)
  for var in "${daos_vars[@]}"; do
    # shellcheck disable=SC2163
    export "$var"
  done
}

env_load() {
  local env_file="${1:-"${DAOS_IO500_ENV_FILE}"}"
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

io500_create_ini() {
  DAOS_IO500_INI="${SCRIPT_DIR}/${SCRIPT_FILE%.*}.${TIMESTAMP}.ini"
  log.info "Create IO500 config file: ${DAOS_IO500_INI}"
  local client_count=$(cat ${DAOS_CLIENT_HOSTS_FILE} | wc -l)
  DAOS_IO500_NPROC=$(( $client_count * $(nproc --all) ))
  DAOS_IO500_PPN=$(( $(nproc --all) ))
  DAOS_IO500_RUN_RESULTS_DIR="${DAOS_IO500_RESULTS_DIR}/${TIMESTAMP}"
  env_export
  log.debug.vars
  log.debug "envsubst < \"${DAOS_IO500_INI_ENVTPL}\" > \"${DAOS_IO500_INI}\""
  envsubst < "${DAOS_IO500_INI_ENVTPL}" > "${DAOS_IO500_INI}"
}

run_cmd_servers() {
  local cmd="$1"
  clush --hostfile="${DAOS_SERVER_HOSTS_FILE}" --dsh "${cmd}"
}

run_cmd_clients() {
  local cmd="$1"
  clush --hostfile="${DAOS_CLIENT_HOSTS_FILE}" --dsh "${cmd}"
}

unmount_dfuse() {
  log.info "Unmounting dfuse dir: ${DAOS_IO500_DFUSE_DIR}"
  run_cmd_clients "if findmnt --target '${DAOS_IO500_DFUSE_DIR}' > /dev/null; then sudo fusermount3 -u '${DAOS_IO500_DFUSE_DIR}'; fi"
  run_cmd_clients "rm -rf '${DAOS_IO500_DFUSE_DIR}'"
}

stop_clients() {
  log.info "Stopping daos_agent service on clients"
  run_cmd_clients "if sudo systemctl is-active daos_agent | grep -q active; then sudo systemctl stop daos_agent;fi"

}

format_storage() {
  local server_count=$(cat ${DAOS_SERVER_HOSTS_FILE} | wc -l)
  log.info "Format DAOS storage"
  run_cmd_servers "sudo dmg -l '127.0.0.1' storage format"

  log.info "Waiting for DAOS storage format to finish ... "
  while true; do
    if [[ $(sudo dmg system query -v | grep -c -i joined) -eq ${server_count} ]]; then
      printf "\n"
      log.info "DAOS storage format finished"
      sudo dmg system query -v
      break
    fi
    printf "%s" "."
    sleep 5
  done
}


clean_storage() {
  log.info "Cleaning DAOS storage"
  run_cmd_servers 'sudo systemctl stop daos_server'
  run_cmd_servers 'sudo rm -rf /var/daos/ram/*'
  run_cmd_servers 'sudo rm -rf /var/daos/*.log'
  run_cmd_servers '[[ -d /var/daos/ram ]] && sudo umount /var/daos/ram/ || echo "/var/daos/ram/ unmounted"'
  run_cmd_servers 'sudo systemctl start daos_server'
  # shellcheck disable=SC2016
  run_cmd_servers 'while /bin/netstat -an | /bin/grep \:10001 | /bin/grep -q LISTEN; [ $? -ne 0 ]; do let TRIES-=1; if [ $TRIES -gt 1 ]; then echo "waiting ${TRIES}"; sleep $WAIT;else echo "Timed out";break; fi;done'
  log.info "Finished cleaning storage on DAOS servers"

  log.info "Restarting daos_agent service on DAOS client instances"
  run_cmd_clients 'sudo systemctl restart daos_agent'
  log.info "Finished restarting daos_agent service on DAOS client instances"
}

storage_scan() {
  log.info "DAOS storage scan"
  sudo dmg storage scan
  echo
}

show_storage_usage() {
  log.info "Display storage usage"
  sudo dmg storage query usage
  echo
}

create_pool() {
  log.info "Create pool: ${DAOS_POOL}"
  sudo dmg pool create --size="100%" "${DAOS_POOL}"
  log.info "Setting pool property: reclaim=disabled"
  sudo dmg pool set-prop "${DAOS_POOL}" "reclaim:disabled"
  sudo dmg pool update-acl "${DAOS_POOL}" -e "A::daos_admin@:rwdtTaAo"

  log.info "Pool created successfully"
  sudo dmg pool query "${DAOS_POOL}"
}

create_container() {
  log.info "Create container: ${DAOS_CONT}"

  if ! daos container list "${DAOS_POOL}" | grep -q "${DAOS_CONT}"; then
    daos container create \
      --type=POSIX \
      --chunk-size="${DAOS_CONT_CHUNK_SIZE}" \
      --properties="${DAOS_CONT_REPLICATION_FACTOR}" \
      "${DAOS_POOL}" \
      "${DAOS_CONT}"
  fi

  log.info "Show container properties"
  daos cont get-prop "${DAOS_POOL}" "${DAOS_CONT}"
}

mount_dfuse() {
  if [[ -d "${DAOS_IO500_DFUSE_DIR}" ]]; then
    log.warn "DFuse dir ${DAOS_IO500_DFUSE_DIR} already exists."
  else
    log.info "Use dfuse to mount ${DAOS_CONT} on ${DAOS_IO500_DFUSE_DIR}"
    run_cmd_clients "mkdir -p '${DAOS_IO500_DFUSE_DIR}'"
    run_cmd_clients "dfuse -S --pool='${DAOS_POOL}' --container='${DAOS_CONT}' --mountpoint='${DAOS_IO500_DFUSE_DIR}'"

    local counter=0
    local max_tries=120
    while ! findmnt --target "${DAOS_IO500_DFUSE_DIR}"; do
      sleep 1
      if [[ $counter -lt $max_tries ]]; then
        counter=$((counter + 1))
      else
        log.error "Failed to mount '${DAOS_IO500_DFUSE_DIR}' with dfuse"
        exit 1
      fi
    done

    log.info "DFuse mount complete!"

    # Create directories for io500 data on dfuse mount
    mkdir -p "${DAOS_IO500_DFUSE_DATA_DIR}"
    mkdir -p "${DAOS_IO500_RESULTS_DIR}"
  fi
}



run_io500() {
  log.info "Load Intel MPI"
  export MFU_POSIX_TS=1
  export I_MPI_OFI_LIBRARY_INTERNAL=0
  export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"
  source /opt/intel/oneapi/setvars.sh

  export PATH=$PATH:${DAOS_IO500_INSTALL_DIR}/bin

  mpirun -np ${DAOS_IO500_NPROC} \
    -ppn ${DAOS_IO500_PPN} \
    --hostfile "${DAOS_CLIENT_HOSTS_FILE}" \
    $MPI_RUN_OPTS \
    "${DAOS_IO500_INSTALL_DIR}/io500" \
    "${DAOS_IO500_INI}"
  log.info "IO500 run complete!"
}

main() {
  verify
  log.section "IO500 Run\nTimestamp: ${TIMESTAMP}\nID: ${RUN_ID}"
  env_load
  log.debug.vars
  io500_create_ini
  stop_clients
  unmount_dfuse
  clean_storage
  format_storage
  storage_scan
  show_storage_usage
  create_pool
  create_container
  mount_dfuse
  run_io500
}

main

# # cleanup() {
# # #   log.info "Clean up DAOS storage"
# # #   unmount_dfuse
# # #   "${SCRIPT_DIR}/clean_storage.sh"

# #   log.info "Clean DAOS storage"
# #   run_cmd_servers --dsh 'sudo systemctl stop daos_server'
# #   run_cmd_servers --dsh 'sudo rm -rf /var/daos/ram/*'
# #   run_cmd_servers --dsh 'sudo rm -rf /var/daos/*.log'
# #   run_cmd_servers --dsh '[[ -d /var/daos/ram ]] && sudo umount /var/daos/ram/ || echo "/var/daos/ram/ unmounted"'
# #   run_cmd_servers --dsh 'sudo systemctl start daos_server'
# #   # shellcheck disable=SC2016
# #   run_cmd_servers --dsh 'while /bin/netstat -an | /bin/grep \:10001 | /bin/grep -q LISTEN; [ $? -ne 0 ]; do let TRIES-=1; if [ $TRIES -gt 1 ]; then echo "waiting ${TRIES}"; sleep $WAIT;else echo "Timed out";break; fi;done'
# #   log.info "Finished cleaning storage on DAOS servers"

# #   log.info "Restarting daos_agent service on DAOS client instances"
# #   run_cmd_clients'sudo systemctl restart daos_agent'
# # }


# # use_old_cli() {
# #   local daos_version
# #   daos_version=$(rpm -q --queryformat '%{VERSION}' daos)
# #   awk 'BEGIN{if(ARGV[1]<ARGV[2])exit 0;exit 1;}' "${daos_version}" "2.3"
# #   return $?
# # }



# # create_container() {
# #   log.info "Create container: label=${DAOS_CONT}"

# #   if ! daos container list "${DAOS_POOL}" | grep -q "${DAOS_CONT}"; then
# #     if use_old_cli; then
# #       # Use older DAOS v2.2.x dmg options
# #       daos container create --type=POSIX \
# #         --chunk-size="${DAOS_CHUNK_SIZE}" \
# #         --properties="${DAOS_CONT_REPLICATION_FACTOR}" \
# #         --label="${DAOS_CONT}" \
# #         "${DAOS_POOL}"
# #     else
# #       daos container create --type=POSIX \
# #         --chunk-size="${DAOS_CHUNK_SIZE}" \
# #         --properties="${DAOS_CONT_REPLICATION_FACTOR}" \
# #         "${DAOS_POOL}" \
# #         "${DAOS_CONT}"
# #     fi
# #   fi

# #   log.info "Show container properties"
# #   daos cont get-prop "${DAOS_POOL}" "${DAOS_CONT}"
# # }





# # run_io500() {
# #   log.debug "COMMAND: mpirun -np ${IO500_NP} -ppn ${IO500_PPN} --hostfile ${SCRIPT_DIR}/hosts_clients ${MPI_RUN_OPTS} ${IO500_DIR}/io500 temp.ini"
# #   # shellcheck disable=SC2086
# #   mpirun -np ${IO500_NP} \
# #     -ppn ${IO500_PPN} \
# #     --hostfile "${SCRIPT_DIR}/hosts_clients" \
# #     $MPI_RUN_OPTS \
# #     "${IO500_DIR}/io500" \
# #     temp.ini
# #   log.info "IO500 run complete!"
# # }

# # show_pool_state() {
# #   log.info "Query pool state"
# #   dmg pool query "${DAOS_POOL}"
# # }

# # process_results() {
# #   log.info "Copy results from ${IO500_RESULTS_DFUSE_DIR} to ${IO500_RESULTS_DIR_TIMESTAMPED}"

# #   cp config.sh "${IO500_RESULTS_DIR_TIMESTAMPED}/"
# #   cp hosts* "${IO500_RESULTS_DIR_TIMESTAMPED}/"

# #   echo "${TIMESTAMP}" >"${IO500_RESULTS_DIR_TIMESTAMPED}/io500_run_timestamp.txt"

# #   FIRST_SERVER=$(echo "${DAOS_SERVER_LIST}" | cut -d, -f1)
# #   ssh "${FIRST_SERVER}" 'daos_server version' > \
# #     "${IO500_RESULTS_DIR_TIMESTAMPED}/daos_server_version.txt"

# #   RESULT_SERVER_FILES_DIR="${IO500_RESULTS_DIR_TIMESTAMPED}/server_files"
# #   # shellcheck disable=SC2013
# #   for server in $(cat hosts_servers); do
# #     SERVER_FILES_DIR="${RESULT_SERVER_FILES_DIR}/${server}"
# #     mkdir -p "${SERVER_FILES_DIR}/etc/daos"
# #     scp "${server}:/etc/daos/*.yaml" "${SERVER_FILES_DIR}/etc/daos/"
# #     scp "${server}:/etc/daos/*.yml" "${SERVER_FILES_DIR}/etc/daos/"
# #     mkdir -p "${SERVER_FILES_DIR}/var/daos"
# #     scp "${server}:/var/daos/*.log*" "${SERVER_FILES_DIR}/var/daos/"
# #     ssh "${server}" 'daos_server version' >"${SERVER_FILES_DIR}/daos_server_version.txt"
# #   done

# #   # Save a copy of the environment variables for the IO500 run
# #   printenv | sort >"${IO500_RESULTS_DIR_TIMESTAMPED}/env.sh"

# #   # Copy results from dfuse mount to another directory so we don't lose them
# #   # when the dfuse mount is removed
# #   rsync -avh "${IO500_RESULTS_DFUSE_DIR}/" "${IO500_RESULTS_DIR_TIMESTAMPED}/"
# #   cp temp.ini "${IO500_RESULTS_DIR_TIMESTAMPED}/"

# #   # Save output from "dmg pool query"
# #   # shellcheck disable=SC2024
# #   dmg pool query "${DAOS_POOL}" > \
# #     "${IO500_RESULTS_DIR_TIMESTAMPED}/dmg_pool_query_${DAOS_POOL}.txt"

# #   log.info "Results files located in ${IO500_RESULTS_DIR_TIMESTAMPED}"

# #   RESULTS_TAR_FILE="${IO500_TEST_CONFIG_ID}_${TIMESTAMP}.tar.gz"

# #   log.info "Creating '${HOME}/${RESULTS_TAR_FILE}' file with contents of ${IO500_RESULTS_DIR_TIMESTAMPED} directory"
# #   pushd "${IO500_RESULTS_DIR_TIMESTAMPED}"
# #   tar -czf "${HOME}/${RESULTS_TAR_FILE}" ./
# #   log.info "Results tar file: ${HOME}/${RESULTS_TAR_FILE}"
# #   popd
# # }

# # main() {
# #   log.section "Prepare for IO500 run"
# #   log.debug.show_vars
# #   fix_admin_cert_permissions
# #   cleanup
# #   storage_scan
# #   format_storage
# #   show_storage_usage
# #   create_pool
# #   create_container
# #   mount_dfuse
# #   io500_create_ini
# #   log.section "Run IO500"
# #   run_io500
# #   process_results
# #   unmount_dfuse
# # }

# # main
