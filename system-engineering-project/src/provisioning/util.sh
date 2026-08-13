#! /bin/bash
#
# Utility functions that are useful in all provisioning scripts.

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

# Set to 'yes' if debug messages should be printed.
readonly debug_output='yes'

#------------------------------------------------------------------------------
# Logging and debug output
#------------------------------------------------------------------------------
# Six levels of logging are provided: 
# - log (white, for messages you always want to see)
# - debug (magenta, for debug output that you only want to see if specified)
# - error (red, obviously, for error messages)
# - success (green, for confirming that a specific task or check has passed)
# - warn (yellow, for non-critical issues or things that require user attention)
# - info (cyan, for highlighting important summary information or final results)

# Usage: log [ARG]...
#
# Prints all arguments on the standard error stream
log() {
  printf '\e[0;37m[LOG]  %s\e[0m\n' "${*}" 1>&2
}

# Usage: debug [ARG]...
#
# Prints all arguments on the standard error stream
debug() {
  if [ "${debug_output}" = 'yes' ]; then
    printf '\e[0;35m[DBG] %s\e[0m\n' "${*}" 1>&2
  fi
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf '\e[0;31m[ERR] %s\e[0m\n' "${*}" 1>&2
}

# Usage: success [ARG]...
#
# Prints all arguments on the standard error stream
success() {
  printf '\e[0;32m[OK]  %s\e[0m\n' "${*}" 1>&2
}

# Usage: warn [ARG]...
#
# Prints all arguments on the standard error stream
warn() {
  printf '\e[0;33m[WRN]  %s\e[0m\n' "${*}" 1>&2
}

# Usage: info [ARG]...
#
# Prints all arguments on the standard error stream
info() {
  printf '\e[0;36m[INFO] %s\e[0m\n' "${*}" 1>&2
}

#------------------------------------------------------------------------------
# Execution Helpers
#------------------------------------------------------------------------------

# Usage: run <command>
#
# Executes commands with optional debug suppression. 
run() {
  if [ "${DEBUG:-0}" -eq 1 ]; then "$@"; else "$@" > /dev/null 2>&1; fi
}

# Usage: install_package <pkg1> [pkg2]...
#
# Installs packages via DNF and verifies success.
install_package() {
  while [ "$#" -gt 0 ]; do
    if run dnf install -y -q "$1"; then success "$1 installed."; else
      error "Failed to install $1."; return 1
    fi
    shift
  done
}

# Usage: verify "<description>" <command>
#
# Aborts script if a vital condition is not met.
verify() {
  local description="$1"; shift
  if "$@" > /dev/null 2>&1; then success "VERIFIED: ${description}"; else
    error "VERIFICATION FAILED: ${description}"
    error "Aborting provisioning - fix the above issue before continuing."
    exit 1
  fi
}

#------------------------------------------------------------------------------
# Useful tests
#------------------------------------------------------------------------------

# Usage: files_differ FILE1 FILE2
#
# Tests whether the two specified files have different content
#
# Returns with exit status 0 if the files are different, a nonzero exit status
# if they are identical.
files_differ() {
  local file1="${1}"
  local file2="${2}"

  # If the second file doesn't exist, it's considered to be different
  if [ ! -f "${file2}" ]; then
    return 0
  fi

  local -r checksum1=$(md5sum "${file1}" | cut -c 1-32)
  local -r checksum2=$(md5sum "${file2}" | cut -c 1-32)

  [ "${checksum1}" != "${checksum2}" ]
}

# Usage:
#
# Tests whether file allready exists. If not, an empty file is created.
ensure_file_exists() {
  local filepath="$1"

  if [[ -f "${filepath}" ]]; then
    log " -> file already exists"
  else
    warn "File not found, creating: ${filepath}"
    touch "${filepath}"
    success " -> created empty file: ${filepath}"
  fi
}


#------------------------------------------------------------------------------
# SELinux
#------------------------------------------------------------------------------

# Usage: ensure_sebool VARIABLE
#
# Ensures that an SELinux boolean variable is turned on
ensure_sebool()  {
  local -r sebool_variable="${1}"
  local -r current_status=$(getsebool "${sebool_variable}")

  if [ "${current_status}" != "${sebool_variable} --> on" ]; then
    setsebool -P "${sebool_variable}" on
  fi
}

# Usage: ensure_fcontext CONTEXT PATH
#
# Registers an SELinux file context and applies it to the path
ensure_fcontext() {
  local -r context="${1}"
  local -r path="${2}"
  local -r regex="${path}(/.*)?"

  log "Ensuring SELinux context ${context} for ${path} (recursive)"

  # 1. Check if path has a specific definition
  sudo semanage fcontext -a -t "${context}" "${regex}" > /dev/null 2>&1 || true

  # 2. Apply to the filesystem
  sudo restorecon -R "${path}" > /dev/null 2>&1
}

#------------------------------------------------------------------------------
# User management
#------------------------------------------------------------------------------

# Usage: ensure_user_exists USERNAME
#
# Create the user with the specified name if it doesn’t exist
ensure_user_exists() {
  local user="${1}"
  shift

  log "Ensure user ${user} exists"
  if ! getent passwd "${user}"; then
    log " -> user added"
    useradd "$@" "${user}"
  else
    log " -> already exists"
  fi
}

# Usage: ensure_group_exists GROUPNAME
#
# Creates the group with the specified name, if it doesn’t exist
ensure_group_exists() {
  local group="${1}"

  log "Ensure group ${group} exists"
  if ! getent group "${group}"; then
    log " -> group added"
    groupadd "${group}"
  else
    log " -> already exists"
  fi
}

# Usage: assign_groups USER GROUP...
#
# Adds the specified user to the specified groups
assign_groups() {
  local user="${1}"
  shift
  log "Adding user ${user} to groups: ${*}"
  while [ "$#" -ne "0" ]; do
    usermod -aG "${1}" "${user}"
    shift
  done
}

#------------------------------------------------------------------------------
# Network helpers
#------------------------------------------------------------------------------
 
# Usage: find_vlan_iface
#
# Finds the interface carrying a 192.168.132.x address.
# Prints "<iface> <ip> <prefix>" on one line, or empty string if not found.
find_vlan_iface() {
  ip -o -4 addr show \
    | awk '/192\.168\.132\./ { split($4,a,"/"); print $2, a[1], a[2]; exit }'
}
 
# Usage: find_nat_iface
#
# Finds the VirtualBox NAT interface (always assigned a 10.0.2.x address).
# Prints the interface name, or empty string if not found.
find_nat_iface() {
  ip -o -4 addr show \
    | awk '/10\.0\.2\./ { print $2; exit }'
}
 
# Usage: get_conn_name IFACE
#
# Returns the NetworkManager connection name active on the given interface.
get_conn_name() {
  local iface="${1}"
  nmcli -g GENERAL.CONNECTION device show "${iface}" 2>/dev/null | head -1
}