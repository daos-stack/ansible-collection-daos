#!/bin/bash
# Copyright 2022-2023 Intel Corporation
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

ANS_DIR="${ANS_DIR:-${HOME}/ansible-daos}"
ANS_VENV_DIR="${ANS_VENV_DIR:-${ANS_DIR}/.venv}"
ANS_INSTALL_COLL="${ANS_INSTALL_COLL:-true}"
ANS_COLL_GIT_URL="${ANS_COLL_GIT_URL:-git+https://github.com/mark-olson/ansible-collection-daos.git,develop}"
ANS_CREATE_INV="${ANS_CREATE_INV:-true}"
ANS_CREATE_CFG="${ANS_CREATE_CFG:-true}"
PKG_MGR_UPDATE="${PKG_MGR_UPDATE:-false}"
ANSIBLE_DEPRECATION_WARNINGS=False

source /etc/os-release

# BEGIN: Logging variables and functions
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1  [WARN]=2 [ERROR]=3 [FATAL]=4 [OFF]=5)
declare -A LOG_COLORS=([DEBUG]=2 [INFO]=12 [WARN]=3 [ERROR]=1 [FATAL]=9 [OFF]=0 [OTHER]=15)
LOG_LEVEL=INFO

log() {
  local msg="$1"
  local lvl=${2:-INFO}
  if [[ ${LOG_LEVELS[$LOG_LEVEL]} -le ${LOG_LEVELS[$lvl]} ]]; then
    if [[ -t 1 ]]; then tput setaf "${LOG_COLORS[$lvl]}"; fi
    printf "[%-5s] %s\n" "$lvl" "${msg}" 1>&2
    if [[ -t 1 ]]; then tput sgr0; fi
  fi
}

log.debug() { log "${1}" "DEBUG" ; }
log.info()  { log "${1}" "INFO"  ; }
log.warn()  { log "${1}" "WARN"  ; }
log.error() { log "${1}" "ERROR" ; }
log.fatal() { log "${1}" "FATAL" ; }
# END: Logging variables and functions

declare -A pkg_mgrs;
pkg_mgrs[almalinux]=dnf
pkg_mgrs[amzn]=yum
pkg_mgrs[centos]=yum
pkg_mgrs[debian]=apt-get
pkg_mgrs[fedora]=dnf
pkg_mgrs[opensuse-leap]=zypper
pkg_mgrs[rhel]=dnf
pkg_mgrs[rocky]=dnf
pkg_mgrs[ubuntu]=apt-get

pkg_mgr="${pkg_mgrs[$ID]}"

declare -A pkg_list;
pkg_list[almalinux]="curl wget git python39"
pkg_list[amzn]="curl wget git python3 python3-pip"
pkg_list[centos]="curl wget git python3 python3-pip"
pkg_list[debian]="curl wget git python3 python3-pip"
pkg_list[fedora]="curl wget git python3 python3-pip"
pkg_list[opensuse-leap]="curl wget git python3 python3-pip"
pkg_list[rhel]="curl wget git python39"
pkg_list[rocky]="curl wget git python39"
pkg_list[ubuntu]="curl wget git python3 python3-pip"

pkgs="${pkg_list[$ID]}"

install_pkgs() {
  log.info "Installing packages"
  if [[ "${PKG_MGR_UPDATE}" == "true" ]]; then
    if [[ "${pkg_mgr}" == "apt" ]]; then
      log.info "Running ${pkg_mgr} update and upgrade"
      "${pkg_mgr}" update
      "${pkg_mgr}" -y upgrade
    else
      log.info "Running ${pkg_mgr} update"
      "${pkg_mgr}" update -y
    fi
  fi
  "${pkg_mgr}" install -y ${pkgs}

  case "$ID" in
    alma | rocky | rhel)
      update-alternatives --set python3 /usr/bin/python3.9
      ;;
    *)
      ;;
  esac
}

create_venv() {
  log.info "Creating python virtualenv in ${ANS_VENV_DIR}"
  mkdir -p "${ANS_VENV_DIR}"
  python3 -m venv "${ANS_VENV_DIR}"
  activate_venv
  log.info "Upgrading pip"
  pip install --upgrade --no-input pip
}

activate_venv() {
  if [[ -z $VIRTUAL_ENV ]]; then
    source "${ANS_VENV_DIR}/bin/activate"
  fi
}

install_ansible() {
  log.info "Installing Ansible"
  activate_venv
  pip install ansible
  echo "export ANSIBLE_DEPRECATION_WARNINGS=True" >> "${ANS_VENV_DIR}/bin/activate"
}

show_versions() {
  activate_venv
  log.info "Python version"
  python3 --version
  log.info "Pip version"
  pip3 --version
  log.info "Ansible version"
  ansible --version
}

install_collection() {
  local collection="daos_stack.daos"

  if [[ "${ANS_INSTALL_COLL}" = "true" ]]; then
    activate_venv

    if ! ansible-galaxy collection list | grep -v 'CryptographyDeprecationWarning' | grep -q "${collection}"; then
      log.info "Installing Ansible Collection: ${collection}"
      ansible-galaxy collection install \
        --clear-response-cache \
        --force-with-deps \
        "${ANS_COLL_GIT_URL}"
    else
      log.info "Collection already installed: ${collection}"
    fi
  fi
}

create_ansible_cfg() {
  if [[ "${ANS_CREATE_CFG}" == "true" ]]; then
    log.info "Creating ansible config file: ${ANS_DIR}/ansible.cfg"
    if [[ ! -f "${ANS_DIR}/ansible.cfg" ]]; then
      cat > "${ANS_DIR}/ansible.cfg" <<EOF
[defaults]
executable=/bin/bash
forks=15
inventory=./hosts
local_tmp=~/.ansible/tmp
deprecation_warnings=False
collections_path=~/.ansible/collections
host_key_checking=False
interpreter_python=auto
system_warnings=False
use_persistent_connections=True

[connection]
pipelining=True

[galaxy]
cache_dir=~/.ansible/galaxy_cache

[inventory]
any_unparsed_is_failed=True

EOF
    fi
  fi
}

create_inventory() {
  if [[ "${ANS_CREATE_INV}" == "true" ]]; then
    log.info "Creating inventory in ${ANS_DIR}"
    mkdir -p "${ANS_DIR}/group_vars/all"
    mkdir -p "${ANS_DIR}/group_vars/daos_admins"
    mkdir -p "${ANS_DIR}/group_vars/daos_clients"
    mkdir -p "${ANS_DIR}/group_vars/daos_servers"

    if [[ ! -f "${ANS_DIR}/group_vars/daos_admins/daos" ]]; then
      cat > "${ANS_DIR}/group_vars/daos_admins/daos" <<EOF
---
daos_roles:
  - admin
  - client
EOF
    fi

    if [[ ! -f "${ANS_DIR}/group_vars/daos_clients/daos" ]]; then
      cat > "${ANS_DIR}/group_vars/daos_clients/daos" <<EOF
---
daos_roles:
  - client

reboot_disable: true

EOF
    fi
    if [[ ! -f "${ANS_DIR}/group_vars/daos_servers/daos" ]]; then
      cat > "${ANS_DIR}/group_vars/daos_servers/daos" <<EOF
---
daos_roles:
  - admin
  - server
EOF
    fi

    if [[ ! -f "${ANS_DIR}/hosts" ]]; then
      cat > "${ANS_DIR}/hosts" <<EOF
[daos_admins]
localhost ansible_connection=local

[daos_clients]

[daos_servers]

[daos_cluster:children]
daos_admins
daos_clients
daos_servers

EOF
    fi
  fi
}

main() {
  log.info "BEGIN: Ansible installation"
  if [[ ! -d "${ANS_VENV_DIR}" ]]; then
    install_pkgs
    create_venv
    install_ansible
  fi
  install_collection
  create_ansible_cfg
  create_inventory
  show_versions
  log.info "END: Ansible installation"
}

main
