#!/usr/bin/env bash

# Install thycotic_cli script.

usage()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") [--help | -h] [--verbose | -v] [--system_bin_dir=<dir>] [--thycotic_cli_executable_name=<name>]

Install thycotic_cli script.

Available options:
  --system_bin_dir=<dir>
      The base directory where the script should be installed. Defaults to "/usr/local/bin".

  --thycotic_cli_executable_name=<name>
      The name that the executable is to be named. Defaults to "thycotic_cli".

  --help, -h
      Print this help and exit.

  --verbose, -v
      Print script debug info.
USAGE_TEXT
}

main()
{
  initialize
  parse_script_params "${@}"
  install_thycotic_cli
}

install_thycotic_cli()
{
  export ANSIBLE_ROLES_PATH=${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/main/:${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/external/

  # Install the dependencies of the playbook:
  ANSIBLE_ROLES_PATH=${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/external/ ansible-galaxy install --role-file=${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/requirements_thycotic_cli.yml --force

  ansible-playbook \
    -v \
    --inventory="localhost," \
    --connection=local \
    --ask-become-pass \
    --extra-vars="adrianjuhl__thycotic_cli__system_bin_dir=${SYSTEM_BIN_DIR}" \
    --extra-vars="adrianjuhl__thycotic_cli__thycotic_cli_executable_name=${THYCOTIC_CLI_EXECUTABLE_NAME}" \
    ${THIS_SCRIPT_DIRECTORY}/../.ansible/playbooks/install_thycotic_cli.yml
}

parse_script_params()
{
  #msg "script params (${#}) are: ${@}"
  # default values of variables set from params
  SYSTEM_BIN_DIR="/usr/local/bin"
  THYCOTIC_CLI_EXECUTABLE_NAME="thycotic_cli"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --system_bin_dir=*)
        SYSTEM_BIN_DIR="${1#*=}"
        ;;
      --thycotic_cli_executable_name=*)
        THYCOTIC_CLI_EXECUTABLE_NAME="${1#*=}"
        ;;
      --help | -h)
        usage
        exit
        ;;
      --verbose | -v)
        set -x
        ;;
      -?*)
        msg "Error: Unknown parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
      *) break ;;
    esac
    shift
  done
}

initialize()
{
  THIS_SCRIPT_PROCESS_ID=$$
  THIS_SCRIPT_DIRECTORY="$(dirname "$(readlink -f "${0}")")"
  initialize_abort_script_config
}

initialize_abort_script_config()
{
  # Exit shell script from within the script or from any subshell within this script - adapted from:
  # https://cravencode.com/post/essentials/exit-shell-script-from-subshell/
  # Exit with exit status 1 if this (top level process of this script) receives the SIGUSR1 signal.
  # See also the abort_script() function which sends the signal.
  trap "exit 1" SIGUSR1
}

abort_script()
{
  echo >&2 "aborting..."
  kill -SIGUSR1 ${THIS_SCRIPT_PROCESS_ID}
  exit
}

msg()
{
  echo >&2 -e "${@}"
}

# Main entry into the script - call the main() function
main "${@}"
