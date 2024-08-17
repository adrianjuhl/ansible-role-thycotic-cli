#!/usr/bin/env bash

# Interact with Thycotic from the command line.

usage()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}")
Usage:  ${THIS_SCRIPT_NAME}
            [--thycotic_host_url=<url>]
            [--help | -h]
            [--version]
            [--script_debug]
            <command> [<args>]

Interact with Thycotic from the command line.

Available commands:
  get              Return a secret
  authenticate     Return an authentication token

General options:
    --thycotic_host_url
        The base URL of the Thycotic API service (e.g. https://my-thycotic-secret-server.com) (required if not otherwise provided, see below)
    --help, -h
        Print this help and exit.
    --version
        Print version info and exit.
    --script_debug
        Print script debug info.

If --thycotic_host_url is not supplied, the environment variable THYCOTIC_CLI_THYCOTIC_HOST_URL will be used.

See '${THIS_SCRIPT_NAME} <command> --help' for help on a specific command.
USAGE_TEXT
}

usage_get()
{
  cat <<USAGE_TEXT
Usage: ${THIS_SCRIPT_NAME} get <args>

Get a secret.

get args:
  --secret_id=<id>
      The ID of the secret to return (required)
  --field_id=<id>
      The 'FieldId' of the 'SecretItem' of the secret to return (optional, recommended for secrets that have multiple secret items)
  --access_token=<token>
      The API access token with which to access Thycotic (optional, see notes below)
  --as_xml
      Returns the secret's full XML structure

The API access token may alternatively be provided by setting the environment variable THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN.

If the API access token isn't provided then the user will be prompted for their credentials to thycotic.

If the user needs to be prompted for their credentials, the following environment variables are used if set:
  THYCOTIC_CLI_GET_USERNAME_COMMAND    if set, the contained command is run to obtain the user's username
  THYCOTIC_CLI_GET_PASSWORD_COMMAND    if set, the contained command is run to obtain the user's password
USAGE_TEXT
}

usage_authenticate()
{
  cat <<USAGE_TEXT
Usage: ${THIS_SCRIPT_NAME} authenticate

Get an API access token.

Use the following to save the token:
$ export THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=\$(${THIS_SCRIPT_NAME} authenticate)
USAGE_TEXT
}

main()
{
  initialize
  parse_script_params "${@}"
  THYCOTIC_CLI_CURL_VERBOSE=""
  if [ "${SCRIPT_DEBUG_OPTION}" == "${TRUE_STRING}" ]; then
    THYCOTIC_CLI_CURL_VERBOSE=" -v "
  fi
  case "${THYCOTIC_CLI_COMMAND}" in
    get)
      handle_command_get "${@}"
      ;;
    authenticate)
      handle_command_authenticate "${@}"
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
  echo "${THYCOTIC_CLI_SECRET_VALUE}"
}

handle_command_authenticate()
{
  parse_script_params_authenticate "${@}"
  THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=""
  get_thycotic_api_access_token
  echo "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}"
}

get_thycotic_secret()
{
  get_thycotic_api_access_token
  catch_stdouterr_pre_actions
  catch_stdouterr curl_thycotic_response curl_thycotic_stderr curl_thycotic_get_secret
  curl_thycotic_return_code="$?"
  catch_stdouterr_post_actions
  if [ "${curl_thycotic_return_code}" -gt 0 ]; then
    msg "Error: Failed to get secret."
    msg "       Call to Thycotic server to get secret failed with return code: ${curl_thycotic_return_code}"
    msg "       Error message from Thycotic:"
    msg "----"
    msg "${curl_thycotic_stderr}"
    msg "----"
    abort_script
  fi
  thycotic_errors=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:GetSecretResult/s:Errors" 2>/dev/null)
  if [ -n "${thycotic_errors}" ]; then
    msg "Error: Failed to get secret ${THYCOTIC_CLI_SECRET_ID}. Error message from Thycotic: ${thycotic_errors}"
    abort_script
  fi
  case ${THYCOTIC_CLI_GET_RESPONSE_TYPE} in
    "AS_VALUE")
      if [ -n "${THYCOTIC_CLI_SECRET_ITEM_FIELD_ID}" ]; then
        THYCOTIC_CLI_SECRET_VALUE=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:GetSecretResult/s:Secret/s:Items/s:SecretItem[s:FieldId=${THYCOTIC_CLI_SECRET_ITEM_FIELD_ID}]/s:Value" 2>/dev/null | xmlstarlet unesc 2>/dev/null)
      else
        THYCOTIC_CLI_SECRET_VALUE=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:GetSecretResult/s:Secret/s:Items/s:SecretItem/s:Value" 2>/dev/null | xmlstarlet unesc 2>/dev/null)
      fi
      ;;
    "AS_XML")
      THYCOTIC_CLI_SECRET_VALUE=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --copy-of "/s:GetSecretResult/s:Secret" 2>/dev/null | xmlstarlet format 2>/dev/null)
      ;;
  esac
}

get_thycotic_api_access_token()
{
  if [ -n "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
    # THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN has a non-empty value
    msg "THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN has a value - validating it..."
    validate_thycotic_api_access_token
  else
    msg "THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN does not have a value >>>${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}<<<"
  fi
  if [ -z "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
    get_user_username
    get_user_password
    catch_stdouterr_pre_actions
    catch_stdouterr curl_thycotic_response curl_thycotic_stderr curl_thycotic_authenticate
    curl_thycotic_return_code="$?"
    catch_stdouterr_post_actions
    if [ "${curl_thycotic_return_code}" -gt 0 ]; then
      msg "Error: Failed to obtain Thycotic API Access Token."
      msg "       The command to call the Thycotic server to authenticate failed with return code: ${curl_thycotic_return_code}"
      msg "       Command error message:"
      msg "----"
      msg "${curl_thycotic_stderr}"
      msg "----"
      abort_script
    fi

    API_CALL_RESPONSE=${curl_thycotic_response}
    API_CALL_HTTP_STATUS_ACTUAL=${curl_thycotic_stderr}
    API_CALL_HTTP_STATUS_EXPECTED="200"
    msg "API_CALL_RESPONSE: ${API_CALL_RESPONSE}"
    msg "API_CALL_HTTP_STATUS_ACTUAL: ${API_CALL_HTTP_STATUS_ACTUAL}"
    if [ "${API_CALL_HTTP_STATUS_ACTUAL}" != "${API_CALL_HTTP_STATUS_EXPECTED}" ]; then
      msg "Error: Failed to obtain Thycotic API Access Token."
      msg "       Call to Thycotic server to authenticate failed with HTTP status code: ${API_CALL_HTTP_STATUS_ACTUAL} (expected ${API_CALL_HTTP_STATUS_EXPECTED})"
      msg "       API call response follows:"
      msg "--------"
      msg "${API_CALL_RESPONSE}"
      msg "--------"
      if [ "${API_CALL_HTTP_STATUS_ACTUAL}" == "400" ]; then
        thycotic_error=$(echo "${curl_thycotic_response}" | jq '.error')
        msg "       Error message from Thycotic:"
        msg "       ${thycotic_error}"
      fi
      abort_script
    fi
    #THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:AuthenticateResult/s:Token")
    THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN=$(echo "${curl_thycotic_response}" | jq -r '.access_token')
    if [ -z "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
      msg "Error: Failed to obtain Thycotic Access Token. Thycotic authentication response: ${curl_thycotic_response}"
      abort_script
    fi
  fi
}

get_user_username()
{
  THYCOTIC_USER_USERNAME=""
  if [ -n "${THYCOTIC_CLI_GET_USERNAME_COMMAND}" ]; then
    THYCOTIC_USER_USERNAME=$(${THYCOTIC_CLI_GET_USERNAME_COMMAND})
    last_command_return_code="$?"
    if [ "${last_command_return_code}" -ne 0 ]; then
      msg "Warning: The command contained in THYCOTIC_CLI_GET_USERNAME_COMMAND failed and won't be used."
      THYCOTIC_USER_USERNAME=""
    fi
  fi
  if [ ! -n "${THYCOTIC_USER_USERNAME}" ]; then
    # Prompt for username...
    THYCOTIC_USER_USERNAME_DEFAULT="${THYCOTIC_CLI_USERNAME:-${USER}}"
    echo -n "Please enter your Username [$THYCOTIC_USER_USERNAME_DEFAULT]: " >&2
    read THYCOTIC_USER_USERNAME
    THYCOTIC_USER_USERNAME="${THYCOTIC_USER_USERNAME:-$THYCOTIC_USER_USERNAME_DEFAULT}"
  fi
}

get_user_password()
{
  THYCOTIC_USER_PASSWORD=""
  if [ -n "${THYCOTIC_CLI_GET_PASSWORD_COMMAND}" ]; then
    THYCOTIC_USER_PASSWORD=$(${THYCOTIC_CLI_GET_PASSWORD_COMMAND})
    last_command_return_code="$?"
    if [ "${last_command_return_code}" -ne 0 ]; then
      msg "Warning: The command contained in THYCOTIC_CLI_GET_PASSWORD_COMMAND failed and won't be used."
      THYCOTIC_USER_PASSWORD=""
    fi
  fi
  if [ ! -n "${THYCOTIC_USER_PASSWORD}" ]; then
    # Prompt for password...
    echo -n "Please enter your Password for user $THYCOTIC_USER_USERNAME: " >&2
    read -sr THYCOTIC_USER_PASSWORD
    echo >&2
  fi
}

validate_thycotic_api_access_token()
{
  catch_stdouterr_pre_actions
  catch_stdouterr curl_thycotic_response curl_thycotic_stderr curl_thycotic_get_token_is_valid
  curl_thycotic_return_code="$?"
  catch_stdouterr_post_actions
  if [ "${curl_thycotic_return_code}" -gt 0 ]; then
    msg "Error: Failed to check the validity of the Thycotic API Access Token."
    msg "       Call to Thycotic server to check the validity of the access token failed with return code: ${curl_thycotic_return_code}"
    msg "       Error message from Thycotic:"
    msg "----"
    msg "${curl_thycotic_stderr}"
    msg "----"
    abort_script
  fi
  thycotic_errors=$(echo "${curl_thycotic_response}" | xmlstarlet sel -N s="urn:thesecretserver.com" --template --value-of "/s:TokenIsValidResult/s:Errors" 2>/dev/null)
  if [ -n "${thycotic_errors}" ]; then
    msg "Warning: The provided Thycotic API Access Token is invalid or expired and won't be used. (See: thycotic_cli authenticate --help)"
    msg "         Token validation error messages: ${thycotic_errors}"
    unset THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN
  fi

    msg
    msg "In validate_thycotic_api_access_token"
    API_CALL_RESPONSE=${curl_thycotic_response}
    API_CALL_HTTP_STATUS_ACTUAL=${curl_thycotic_stderr}
    msg "API_CALL_RESPONSE: ${API_CALL_RESPONSE}"
    msg "API_CALL_HTTP_STATUS_ACTUAL: ${API_CALL_HTTP_STATUS_ACTUAL}"
    msg
}

curl_thycotic_authenticate()
{
  #echo "username=${THYCOTIC_USER_USERNAME}&password=${THYCOTIC_USER_PASSWORD}&organization=&domain=uofa" | curl -v -s -H "Content-Type: application/x-www-form-urlencoded" -d @- --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/webservices/sswebservice.asmx/Authenticate"
  echo "grant_type=password&username=${THYCOTIC_USER_USERNAME}&password=${THYCOTIC_USER_PASSWORD}&organization=&domain=uofa" | curl --silent --write-out "%{stderr}%{http_code}" -H "Content-Type: application/x-www-form-urlencoded" -d @- --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/oauth2/token"
}

curl_thycotic_get_secret()
{
  curl -v -s -H "Content-Type: application/x-www-form-urlencoded" -d "secretId=${THYCOTIC_CLI_SECRET_ID}&token=${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/webservices/sswebservice.asmx/GetSecretLegacy"
}

curl_thycotic_get_token_is_valid()
{
  curl -v -s -H "Content-Type: application/x-www-form-urlencoded" -d "token=${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/webservices/sswebservice.asmx/GetTokenIsValid"
}

parse_script_params()
{
  msg "script params (${#}) are: ${@}"
  # default values of variables set from params
  SCRIPT_DEBUG_OPTION="${FALSE_STRING}"
  THYCOTIC_CLI_COMMAND=""
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --help | -h)
        usage
        exit
        ;;
      --script_debug)
        set -x
        SCRIPT_DEBUG_OPTION="${TRUE_STRING}"
        ;;
      --version)
        print_version_info
        exit
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
  THYCOTIC_CLI_SECRET_ITEM_FIELD_ID=""
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
      --field_id=*)
        THYCOTIC_CLI_SECRET_ITEM_FIELD_ID="${1#*=}"
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
  msg "script params (authenticate) (${#}) are: ${@}"
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

print_version_info()
{
  msg "thycotic_cli version 0.7.0"
}

catch_stdouterr()
  # Catch stdout and stderr from a command or function
  # and store the content in named variables.
  # See: https://stackoverflow.com/a/59592881
  # and: https://stackoverflow.com/a/70735935
  # Usage:
  #   catch_stdouterr stdout_var_name stderr_var_name command_or_function [ARG1 [ARG2 [... [ARGn]]]]
  # Usage pattern:
  #   local last_command_return_code
  #   catch_stdouterr_pre_actions
  #   catch_stdouterr CURL_BLAH_STDOUT CURL_BLAH_STDERR curl_blah
  #   last_command_return_code="$?"
  #   catch_stdouterr_post_actions
  #   if [ "${last_command_return_code}" -ne 0 ]; then
  #     ...
{
  {
      IFS=$'\n' read -r -d '' "${1}";
      IFS=$'\n' read -r -d '' "${2}";
      (IFS=$'\n' read -r -d '' _ERRNO_; return "${_ERRNO_}");
  }\
  < <(
    (printf '\0%s\0%d\0' \
      "$(
        (
          (
            (
              { ${3}; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4-
            ) 4>&2- 2>&1- | tr -d '\0' 1>&4-
          ) 3>&1- | exit "$(cat)"
        ) 4>&1-
      )" "${?}" 1>&2
    ) 2>&1
  )
}

catch_stdouterr_pre_actions()
{
  set +x # Temporarily switch off command logging as it alters the resulting output from the function call and breaks the functionality.
}

catch_stdouterr_post_actions()
{
  if [ "${SCRIPT_DEBUG_OPTION}" == "${TRUE_STRING}" ]; then
    set -x
  fi
}

initialize()
{
  set -o pipefail
  THIS_SCRIPT_PROCESS_ID=$$
  initialize_abort_script_config
  initialize_this_script_directory_variable
  initialize_this_script_name_variable
  initialize_true_and_false_strings
}

initialize_this_script_directory_variable()
{
  # Determines the value of THIS_SCRIPT_DIRECTORY, the absolute directory name where this script resides.
  # See: https://www.binaryphile.com/bash/2020/01/12/determining-the-location-of-your-script-in-bash.html
  # See: https://stackoverflow.com/a/67149152
  local last_command_return_code
  THIS_SCRIPT_DIRECTORY=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1; cd -P -- "$(dirname "$(readlink -- "${BASH_SOURCE[0]}" || echo .)")" || exit 1; pwd)
  last_command_return_code="$?"
  if [ "${last_command_return_code}" -gt 0 ]; then
    # This should not occur for the above command pipeline.
    msg
    msg "Error: Failed to determine the value of this_script_directory."
    msg
    abort_script
  fi
}

initialize_this_script_name_variable()
{
  local path_to_invoked_script
  local default_script_name
  path_to_invoked_script="${BASH_SOURCE[0]}"
  default_script_name=""
  if grep -q '/dev/fd' <(dirname "${path_to_invoked_script}"); then
    # The script was invoked via process substitution
    if [ -z "${default_script_name}" ]; then
      THIS_SCRIPT_NAME="<script invoked via file descriptor (process substitution) and no default name set>"
    else
      THIS_SCRIPT_NAME="${default_script_name}"
    fi
  else
    THIS_SCRIPT_NAME="$(basename "${path_to_invoked_script}")"
  fi
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
