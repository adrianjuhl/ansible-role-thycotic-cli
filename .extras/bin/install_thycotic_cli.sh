#!/usr/bin/env bash

# Install thycotic_cli script.

usage()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}")
           [--install_bin_dir=<dir>]
           [--thycotic_cli_executable_name=<name>]
           [--requires_become=<true|false>]
           [--dry_run] [--show_diff] [--help | -h] [--verbose | -v]

Install thycotic_cli script.

Available options:
  --install_bin_dir=<dir>
      The directory where thycotic_cli is to be installed. Defaults to "/usr/local/bin".
  --thycotic_cli_executable_name=<name>
      The name that the executable is to be named. Defaults to "thycotic_cli".
  --requires_become=<true|false>
      Is privilege escalation required? Defaults to true.
  --dry_run
      Run the role without making changes.
  --show_diff
      Run the role in diff mode.
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
  export ANSIBLE_ROLES_PATH=${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/:${HOME}/.ansible/roles/

  # Install the dependencies of the playbook:
  ANSIBLE_ROLES_PATH=${HOME}/.ansible/roles/ ansible-galaxy install --role-file=${THIS_SCRIPT_DIRECTORY}/../.ansible/roles/requirements_thycotic_cli.yml --force
  last_command_return_code="$?"
  if [ "${last_command_return_code}" -ne 0 ]; then
    msg "Error: ansible-galaxy role installations failed."
    abort_script
  fi

  ASK_BECOME_PASS_OPTION=""
  if [ "${REQUIRES_BECOME}" = "${TRUE_STRING}" ]; then
    ASK_BECOME_PASS_OPTION="--ask-become-pass"
  fi

  ansible-playbook ${ANSIBLE_CHECK_MODE_ARGUMENT} ${ANSIBLE_DIFF_MODE_ARGUMENT} ${ASK_BECOME_PASS_OPTION} -v \
    --inventory="localhost," \
    --connection=local \
    --extra-vars="adrianjuhl__thycotic_cli__install_bin_dir=${INSTALL_BIN_DIR}" \
    --extra-vars="adrianjuhl__thycotic_cli__thycotic_cli_executable_name=${THYCOTIC_CLI_EXECUTABLE_NAME}" \
    --extra-vars="local_playbook__install_thycotic_cli__requires_become=${REQUIRES_BECOME}" \
    ${THIS_SCRIPT_DIRECTORY}/../.ansible/playbooks/install_thycotic_cli.yml
}

parse_script_params()
{
  #msg "script params (${#}) are: ${@}"
  # default values of variables set from params
  INSTALL_BIN_DIR="/usr/local/bin"
  THYCOTIC_CLI_EXECUTABLE_NAME="thycotic_cli"
  REQUIRES_BECOME="${TRUE_STRING}"
  REQUIRES_BECOME_PARAM=""
  ANSIBLE_CHECK_MODE_ARGUMENT=""
  ANSIBLE_DIFF_MODE_ARGUMENT=""
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --install_bin_dir=*)
        INSTALL_BIN_DIR="${1#*=}"
        ;;
      --thycotic_cli_executable_name=*)
        THYCOTIC_CLI_EXECUTABLE_NAME="${1#*=}"
        ;;
      --requires_become=*)
        REQUIRES_BECOME_PARAM="${1#*=}"
        ;;
      --dry_run)
        ANSIBLE_CHECK_MODE_ARGUMENT="--check"
        ;;
      --show_diff)
        ANSIBLE_DIFF_MODE_ARGUMENT="--diff"
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
  case "${REQUIRES_BECOME_PARAM}" in
    "true")
      REQUIRES_BECOME="${TRUE_STRING}"
      ;;
    "false")
      REQUIRES_BECOME="${FALSE_STRING}"
      ;;
    "")
      REQUIRES_BECOME="${TRUE_STRING}"
      ;;
    *)
      msg "Error: Invalid requires_become param value: ${REQUIRES_BECOME_PARAM}, expected one of: true, false"
      abort_script
      ;;
  esac
  #echo "REQUIRES_BECOME_PARAM is: ${REQUIRES_BECOME_PARAM}"
  #echo "REQUIRES_BECOME is: ${REQUIRES_BECOME}"
}

initialize()
{
  set -o pipefail
  THIS_SCRIPT_PROCESS_ID=$$
  initialize_this_script_directory_variable
  initialize_abort_script_config
  initialize_true_and_false_strings
}

initialize_this_script_directory_variable()
{
  # THIS_SCRIPT_DIRECTORY where this script resides.
  # See: https://www.binaryphile.com/bash/2020/01/12/determining-the-location-of-your-script-in-bash.html
  # See: https://stackoverflow.com/a/67149152
  THIS_SCRIPT_DIRECTORY=$(cd "$(dirname -- "$BASH_SOURCE")"; cd -P -- "$(dirname "$(readlink -- "$BASH_SOURCE" || echo .)")"; pwd)
}

initialize_true_and_false_strings()
{
  # Bash doesn't have a native true/false, just strings and numbers,
  # so this is as clear as it can be, using, for example:
  # if [ "${my_boolean_var}" = "${TRUE_STRING}" ]; then
  # where previously 'my_boolean_var' is set to either ${TRUE_STRING} or ${FALSE_STRING}
  TRUE_STRING="true"
  FALSE_STRING="false"
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
