#!/usr/bin/env bash

# Interact with Thycotic from the command line.

usage()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") [--help | -h] [--verbose | -v]
                    [--thycotic_host_url=<url>]
                    <command> [<args>]

Interact with Thycotic from the command line.

Available commands:
  get              Return a secret
  authenticate     Return an authentication token

General options:
  --thycotic_host_url  The base URL of the Thycotic API service (e.g. https:/my-thycotic-secret-server.com) (required if not otherwise provided, see below)
  --help, -h           Print this help and exit
  --verbose, -v        Print script debug info

If --thycotic_host_url is not supplied, the environment variable THYCOTIC_CLI_THYCOTIC_HOST_URL will be used.

See '$(basename "${BASH_SOURCE[0]}") <command> --help' for help on a specific command.
USAGE_TEXT
}

usage_get()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") get <args>

Get a secret.

get args:
  --secret_id=<id>        The ID of the secret to return (required)
  --access_token=<token>  The API access token with which to access Thycotic (required if not otherwise provided, see below)
  --as_xml                Returns the secret's full XML structure

If --access_token is not supplied, the environment variable THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN will be used.
USAGE_TEXT
}

usage_authenticate()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") authenticate

Get an API access token.
USAGE_TEXT
}

main()
{
  initialize
  parse_script_params "${@}"
  THYCOTIC_CLI_CURL_VERBOSE=""
  if [ "${THYCOTIC_CLI_VERBOSE}" == "true" ]; then
    THYCOTIC_CLI_CURL_VERBOSE=" -v "
  fi
  case "${THYCOTIC_CLI_COMMAND}" in
    get)
      handle_command_get "${@}"
      echo "${THYCOTIC_CLI_SECRET_VALUE}"
      ;;
    authenticate)
      handle_command_authenticate "${@}"
      echo "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}"
      ;;
    *)
      msg "Error: Unknown command: ${THYCOTIC_CLI_COMMAND}"
      msg "Use --help for usage help"
      abort_script
      ;;
  esac
}

handle_command_get()
{
  parse_script_params_get "${@}"
  # Ensure secret_id is an integer before calling thycotic (as thycotic responds with a plaintext response rather than XML for this error)
  integer_regex='^[0-9]+$'
  if ! [[ ${THYCOTIC_CLI_SECRET_ID} =~ ${integer_regex} ]] ; then
    msg "Error: secret_id is not a number."
    abort_script
  fi
  get_thycotic_secret
}

handle_command_authenticate()
{
  parse_script_params_authenticate "${@}"
  THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=""
  get_thycotic_api_access_token
}

get_thycotic_secret()
{
  get_thycotic_api_access_token
  local thycotic_get_secret_response=$(curl ${THYCOTIC_CLI_CURL_VERBOSE} -s -H "Content-Type: application/x-www-form-urlencoded" -d "secretId=${THYCOTIC_CLI_SECRET_ID}&token=${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/webservices/sswebservice.asmx/GetSecretLegacy")
  local thycotic_errors=$(echo "${thycotic_get_secret_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:GetSecretResult/s:Errors" 2>/dev/null)
  if [ -n "${thycotic_errors}" ]; then
    msg "Error: Failed to get secret ${THYCOTIC_CLI_SECRET_ID}. Error message from Thycotic: ${thycotic_errors}"
    abort_script
  fi
  case ${THYCOTIC_CLI_GET_RESPONSE_TYPE} in
    "AS_VALUE")
      THYCOTIC_CLI_SECRET_VALUE=$(echo "${thycotic_get_secret_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:GetSecretResult/s:Secret/s:Items/s:SecretItem/s:Value" 2>/dev/null)
      ;;
    "AS_XML")
      THYCOTIC_CLI_SECRET_VALUE=$(echo "${thycotic_get_secret_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --copy-of "/s:GetSecretResult/s:Secret" 2>/dev/null | xmlstarlet format 2>/dev/null)
      ;;
  esac
}

get_thycotic_api_access_token()
{
  if [ -z "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
    get_user_username
    get_user_password
    local thycotic_authenticate_response=$(echo "username=${USER_USERNAME}&password=${USER_PASSWORD}&organization=&domain=uofa" | curl ${THYCOTIC_CLI_CURL_VERBOSE} -s -H "Content-Type: application/x-www-form-urlencoded" -d @- --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/webservices/sswebservice.asmx/Authenticate")
    local thycotic_errors=$(echo "${thycotic_authenticate_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:AuthenticateResult/s:Errors" 2>/dev/null)
    if [ -n "${thycotic_errors}" ]; then
      msg "Error: Failed to obtain Thycotic API Access Token. Error message from Thycotic: ${thycotic_errors}"
      abort_script
    fi
    THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=$(echo "${thycotic_authenticate_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:AuthenticateResult/s:Token")
    if [ -z "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
      msg "Error: Failed to obtain Thycotic Access Token. Thycotic authentication response: ${thycotic_authenticate_response}"
      abort_script
    fi
  fi
}

get_user_username()
{
  # Prompt for username...
  USER_USERNAME_DEFAULT="${THYCOTIC_CLI_USERNAME:-${USER}}"
  echo -n "Please enter your Username [$USER_USERNAME_DEFAULT]: " >&2
  read USER_USERNAME
  USER_USERNAME="${USER_USERNAME:-$USER_USERNAME_DEFAULT}"
}

get_user_password()
{
  # Prompt for password...
  echo -n "Please enter your Password for user $USER_USERNAME: " >&2
  read -sr USER_PASSWORD
  echo >&2
}

parse_script_params()
{
  #msg "script params (${#}) are: ${@}"
  # default values of variables set from params
  THYCOTIC_CLI_COMMAND=""
  THYCOTIC_CLI_VERBOSE="false"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --help | -h)
        usage
        exit
        ;;
      --verbose | -v)
        set -x
        THYCOTIC_CLI_VERBOSE="true"
        ;;
      --thycotic_host_url=*)
        THYCOTIC_CLI_THYCOTIC_HOST_URL="${1#*=}"
        ;;
      -?*)
        msg "Error: Unknown parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
      *)
        THYCOTIC_CLI_COMMAND="${1-}"
        break
        ;;
    esac
    shift
  done
  if [ -z "${THYCOTIC_CLI_THYCOTIC_HOST_URL}" ]; then
    msg "Error: Missing required parameter: thycotic_host_url"
    abort_script
  fi
  if [ -z "${THYCOTIC_CLI_COMMAND}" ]; then
    msg "Error: Missing required argument: command"
    abort_script
  fi
}

parse_script_params_get()
{
  #msg "script params (get) (${#}) are: ${@}"
  # default values of variables set from params
  THYCOTIC_CLI_SECRET_ID=""
  THYCOTIC_CLI_GET_RESPONSE_TYPE="AS_VALUE"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      get)
        shift
        break
        ;;
    esac
    shift
  done
  #msg "script params (get remainder) (${#}) are: ${@}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --secret_id=*)
        THYCOTIC_CLI_SECRET_ID="${1#*=}"
        ;;
      --access_token=*)
        THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN="${1#*=}"
        ;;
      --as_xml)
        THYCOTIC_CLI_GET_RESPONSE_TYPE="AS_XML"
        ;;
      --help | -h)
        usage_get
        exit
        ;;
      -?*)
        msg "Error: Unknown get parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
    esac
    shift
  done
  if [ -z "${THYCOTIC_CLI_SECRET_ID}" ]; then
    msg "Error: Missing required parameter: secret_id"
    abort_script
  fi
}

parse_script_params_authenticate()
{
  #msg "script params (authenticate) (${#}) are: ${@}"
  # default values of variables set from params
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      authenticate)
        shift
        break
        ;;
    esac
    shift
  done
  #msg "script params (authenticate remainder) (${#}) are: ${@}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --help | -h)
        usage_authenticate
        exit
        ;;
      -?*)
        msg "Error: Unknown get parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
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
