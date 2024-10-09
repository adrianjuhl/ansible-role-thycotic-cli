#!/usr/bin/env bash

# Interact with Thycotic from the command line.

usage()
{
  cat <<USAGE_TEXT
Usage:  ${THIS_SCRIPT_NAME}
            [--thycotic_host_url=<url>]
            [--access_token=<token>]
            [--help | -h]
            [--version]
            [--script_debug]
            <command> [<args>]

Interact with Thycotic from the command line.

Available commands:
  get_secret              Return a secret JSON structure
  get_secret_field_value  Return the value of a secret field
  authenticate            Return an authentication token

General parameters:
    --thycotic_host_url=<url>
        The base URL of the Thycotic API service (e.g. https://my-thycotic-secret-server.com) (required if not otherwise provided, see below)
    --access_token=<token>
        The API access token with which to access Thycotic (optional, see notes below)
    --help, -h
        Print this help and exit.
    --version
        Print version info and exit.
    --script_debug
        Print script debug info.

Thycotic Host URL
  If --thycotic_host_url is not supplied, the environment variable THYCOTIC_CLI_THYCOTIC_HOST_URL will be used.

Access Token
  The API access token may alternatively be provided by setting the environment variable THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN.

  If the API access token isn't provided then the user will be prompted for their credentials to thycotic.

  If the user needs to be prompted for their credentials, the following environment variables are used if set:
    THYCOTIC_CLI_GET_USERNAME_COMMAND    if set, the contained command is run to obtain the user's username
    THYCOTIC_CLI_GET_PASSWORD_COMMAND    if set, the contained command is run to obtain the user's password

See '${THIS_SCRIPT_NAME} <command> --help' for help on a specific command.
USAGE_TEXT
}

usage_get_secret()
{
  cat <<USAGE_TEXT
Usage: ${THIS_SCRIPT_NAME} get_secret <args>

Get a secret.

Parameters:
  --secret_id=<id>
      The ID of the secret to return (required)
USAGE_TEXT
}

usage_get_secret_field_value()
{
  cat <<USAGE_TEXT
Usage: ${THIS_SCRIPT_NAME} get_secret_field_value <args>

Get the value of a field of a secret.

Parameters:
  --secret_id=<id>
      The ID of the secret to return (required)
  --field_slug=<slug>
      The field 'slug' of the 'SecretItem' of the secret to return (required)
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
    get_secret)
      handle_command_get_secret "${@}"
      ;;
    get_secret_field_value)
      handle_command_get_secret_field_value "${@}"
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

handle_command_get_secret()
{
  parse_script_params_get_secret "${@}"
  get_thycotic_secret
  echo "${THYCOTIC_CLI_SECRET_JSON}"
}

handle_command_get_secret_field_value()
{
  parse_script_params_get_secret_field_value "${@}"
  get_thycotic_secret_field_value
  echo "${THYCOTIC_CLI_SECRET_FIELD_VALUE}"
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
  call_catch_stdouterr "thycotic_get_secret_curl_command"
  thycotic_get_secret__response_json="${catch_stdouterr__stdout}"
  thycotic_get_secret__curl_information_json="${catch_stdouterr__stderr}"
  #msg "thycotic_get_secret__response_json is ${thycotic_get_secret__response_json}"
  #msg "thycotic_get_secret__curl_information_json is ${thycotic_get_secret__curl_information_json}"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret."
    msg "Message UUID: 7b8f8276-ee2f-4040-a8ba-c9fe657419f9"
    msg "The curl command to get the secret from Thycotic failed with return code: ${catch_stdouterr__rc}"
    call_catch_stdouterr "get_json_element_value .errormsg thycotic_get_secret__curl_information_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (errormsg element) from the curl information JSON."
      msg "get_json_element_value return code: ${catch_stdouterr__rc}"
      msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
      msg "The curl command error text is:"
      msg "${thycotic_get_secret__curl_information_json}"
    else
      msg "The curl error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  # Check that the HTTP status is 200
  call_catch_stdouterr "get_http_code_from_curl_information_json thycotic_get_secret__curl_information_json"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret."
    msg "Message UUID: ba36113f-88a6-4564-a169-e83938b16b12"
    msg "Failed to get the HTTP status code (http_code element) from the curl information JSON."
    msg "get_http_code_from_curl_information_json return code: ${catch_stdouterr__rc}"
    msg "get_http_code_from_curl_information_json error message: ${catch_stdouterr__stderr}"
    msg "The curl information JSON is:"
    msg "${thycotic_get_secret__curl_information_json}"
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  curl__http_code="${catch_stdouterr__stdout}"
  if [ "${curl__http_code}" != "200" ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret."
    msg "Message UUID: f4cec091-8a20-43ec-865f-cd543ec335b3"
    msg "The HTTP status code for the 'get secret' call to Thycotic was: ${curl__http_code}  (expected 200)."
    call_catch_stdouterr "get_json_element_value .error thycotic_get_secret__response_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (error element) from the Thycotic get secret response JSON."
      msg "Thycotic get secret response JSON:"
      msg "${thycotic_get_secret__response_json}"
    else
      msg "Thycotic get secret error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  # HTTP status is 200 OK
  # Check that the Content-Type is (or rather, contains) application/json
  call_catch_stdouterr "get_json_element_value .content_type thycotic_get_secret__curl_information_json"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret."
    msg "Message UUID: 7bd848d3-46ef-4499-bd4e-e4e783e2f542"
    msg "Failed to get the Content-Type value (content_type element) from the curl information JSON."
    msg "get_json_element_value return code: ${catch_stdouterr__rc}"
    msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
    msg "The curl information JSON is:"
    msg "${thycotic_get_secret__curl_information_json}"
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  case ${catch_stdouterr__stdout} in
    *application/json* )
      # Content-Type is application/json
      call_catch_stdouterr "get_json_element_value . thycotic_get_secret__response_json"
      if [ "${catch_stdouterr__rc}" -gt 0 ]; then
        msg "/-----------------------------------------------------------"
        msg "Error: Failed to get the secret."
        msg "Message UUID: f9df7043-8a3c-47a3-b6b8-aa629a0fdcdc"
        msg "Failed to parse the response as JSON when the content type was application/json"
        msg "Parse JSON return code: ${catch_stdouterr__rc}"
        msg "Parse JSON error message: ${catch_stdouterr__stderr}"
        msg "Thycotic get secret response JSON:"
        msg "${thycotic_get_secret__response_json}"
        msg "\-----------------------------------------------------------"
        abort_script
      fi
      THYCOTIC_CLI_SECRET_JSON="${catch_stdouterr__stdout}"
      ;;
    * )
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to get the secret."
      msg "Message UUID: 30ebc3eb-ab9e-4200-a4f4-b378ae093249"
      msg "Unexpected content type: ${catch_stdouterr__stdout}"
      msg "Thycotic get secret response JSON:"
      msg "${thycotic_get_secret__response_json}"
      msg "\-----------------------------------------------------------"
      abort_script
      ;;
  esac
}

get_thycotic_secret_field_value()
{
  get_thycotic_api_access_token
  call_catch_stdouterr "thycotic_get_secret_field_curl_command"
  thycotic_get_secret_field__response="${catch_stdouterr__stdout}"
  thycotic_get_secret_field__curl_information_json="${catch_stdouterr__stderr}"
  #msg "thycotic_get_secret_field__response is ${thycotic_get_secret_field__response}"
  #msg "thycotic_get_secret_field__curl_information_json is ${thycotic_get_secret_field__curl_information_json}"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret field."
    msg "Message UUID: 2b2f7369-0e85-49f1-b8bc-b819fcb8bc66"
    msg "The curl command to get the secret field from Thycotic failed with return code: ${catch_stdouterr__rc}"
    call_catch_stdouterr "get_json_element_value .errormsg thycotic_get_secret_field__curl_information_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (errormsg element) from the curl information JSON."
      msg "get_json_element_value return code: ${catch_stdouterr__rc}"
      msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
      msg "The curl command error text is:"
      msg "${thycotic_get_secret_field__curl_information_json}"
    else
      msg "The curl error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  # Check that the HTTP status is 200
  call_catch_stdouterr "get_http_code_from_curl_information_json thycotic_get_secret_field__curl_information_json"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret field."
    msg "Message UUID: 7ffd878a-04c9-473a-ae46-e049c8af5d5b"
    msg "Failed to get the HTTP status code (http_code element) from the curl information JSON."
    msg "get_http_code_from_curl_information_json return code: ${catch_stdouterr__rc}"
    msg "get_http_code_from_curl_information_json error message: ${catch_stdouterr__stderr}"
    msg "The curl information JSON is:"
    msg "${thycotic_get_secret_field__curl_information_json}"
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  curl__http_code="${catch_stdouterr__stdout}"
  if [ "${curl__http_code}" != "200" ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret field."
    msg "Message UUID: 1d97aa42-732b-4880-84f6-b2137b48cfa9"
    msg "The HTTP status code for the 'get secret field' call to Thycotic was: ${curl__http_code}  (expected 200)."
    call_catch_stdouterr "get_json_element_value .error thycotic_get_secret_field__response"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (error element) from the Thycotic get secret field response JSON."
      msg "Thycotic get secret field response:"
      msg "${thycotic_get_secret_field__response}"
    else
      msg "Thycotic get secret field error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  # HTTP status is 200 OK
  # Check that the Content-Type is (or rather, contains) application/json
  call_catch_stdouterr "get_json_element_value .content_type thycotic_get_secret_field__curl_information_json"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to get the secret field."
    msg "Message UUID: b82d5534-690f-41ee-83e8-94390e751381"
    msg "Failed to get the Content-Type value (content_type element) from the curl information JSON."
    msg "get_json_element_value return code: ${catch_stdouterr__rc}"
    msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
    msg "The curl information JSON is:"
    msg "${thycotic_get_secret_field__curl_information_json}"
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  case ${catch_stdouterr__stdout} in
    "application/octet-stream" )
      THYCOTIC_CLI_SECRET_FIELD_VALUE="${thycotic_get_secret_field__response}"
      ;;
    *application/json* )
      # Content-Type is application/json
      call_catch_stdouterr "get_json_element_value . thycotic_get_secret_field__response"
      if [ "${catch_stdouterr__rc}" -gt 0 ]; then
        msg "/-----------------------------------------------------------"
        msg "Error: Failed to get the secret field."
        msg "Message UUID: a6893c48-e73c-4930-9722-f94a09c45f61"
        msg "Failed to parse the response as JSON when the content type was application/json"
        msg "Parse JSON return code: ${catch_stdouterr__rc}"
        msg "Parse JSON error message: ${catch_stdouterr__stderr}"
        msg "Thycotic get secret field response:"
        msg "${thycotic_get_secret_field__response}"
        msg "\-----------------------------------------------------------"
        abort_script
      fi
      THYCOTIC_CLI_SECRET_FIELD_VALUE="${catch_stdouterr__stdout}"
      ;;
    * )
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to get the secret field."
      msg "Message UUID: 9dfb9696-3065-4a56-aea8-cf1f883fd30d"
      msg "Unexpected content type: ${catch_stdouterr__stdout}"
      msg "Thycotic get secret field response:"
      msg "${thycotic_get_secret_field__response}"
      msg "\-----------------------------------------------------------"
      abort_script
      ;;
  esac
}

get_json_element_value()
  # Return the value of the named element from the given JSON
  # Parameters:
  #   ${1}  - the key of the element to get
  #   ${2}  - the name of the variable that contains the JSON
  # Error return codes:
  #   1  - if parameter 1 does not have a value
  #   2  - if parameter 2 does not have a value
  #   3  - if the jq command to determine if the element exists fails
  #   4  - if the element does not exist or is null
  #   5  - if the jq command to get the value of the element fails
{
  #msg "in get_json_element_value"
  #msg "  - getting ${1}"
  #msg "  - json is:"
  #msg "--------------------------"
  #msg "${!2}"
  #msg "--------------------------"
  if [ -z "${1}" ]; then
    echo "Error in get_json_element_value - parameter 1 does not have a value" >&2
    return 1
  fi
  if [ -z "${2}" ]; then
    echo "Error in get_json_element_value - parameter 2 does not have a value" >&2
    return 2
  fi
  jq_has_result="$(jq 'if '"${1}"' == null then false else true end' < <(echo "${!2}"))"
  jq_return_code="$?"
  if [ "${jq_return_code}" -gt 0 ]; then
    return 3
  else
    if [ "${jq_has_result}" == "false" ]; then
      echo "Element ${1} does not exist or is null" >&2
      echo "The json provided (named ${2}) was:" >&2
      echo "-------------------------------------" >&2
      echo "${!2}" >&2
      echo "-------------------------------------" >&2
      return 4
    else
      element_value="$(jq -r "${1}" < <(echo "${!2}"))"
      jq_return_code="$?"
      if [ "${jq_return_code}" -gt 0 ]; then
        echo "An error occurred getting element ${1} from the json." >&2
        echo "The json provided (named ${2}) was:" >&2
        echo "-------------------------------------" >&2
        echo "${!2}" >&2
        echo "-------------------------------------" >&2
        return 5
      else
        echo "${element_value}"
        return 0
      fi
    fi
  fi
}

report_curl_error_and_abort()
  # Parameters:
  #   ${1}  - the error message to report
  #   ${2}  - the curl command return code
  #   ${3}  - the name of the variable that contains the curl information JSON
{
  #msg "in report_curl_error_and_abort - curl json: ${3}"
  msg
  msg "Error:  ${1}"
  msg "        The curl command failed with return code: ${2}"
  call_catch_stdouterr "get_json_element_value .errormsg ${3}"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    report_get_json_element_value_function_call_error_and_abort "${1}" "${catch_stdouterr__rc}" ".errormsg" "${3}"
  else
    msg "        Curl error message:"
    msg "            ${catch_stdouterr__stdout}"
    if [ -n "${catch_stdouterr__stderr}" ]; then
      msg "        get_json_element_value stderr:"
      msg "            ${catch_stdouterr__stderr}"
    fi
  fi
  msg
  abort_script
}

report_get_json_element_value_function_call_error_and_abort()
  # Parameters:
  #   ${1}  - the error message to report
  #   ${2}  - the function call return code
  #   ${3}  - the name of the element
  #   ${4}  - the name of the variable that contains the JSON
{
  msg "Error:  ${1}"
  msg "        Failed to get the ${3} element from the JSON."
  msg "        The get_json_element_value function failed with return code: ${2}"
  msg "json:"
  msg "----"
  msg "${!4}"
  msg "----"
  msg
  abort_script
}

report_thycotic_call_http_code_error_and_abort()
  # Parameters:
  #   ${1}  - the error message to report
  #   ${2}  - the actual HTTP status code
  #   $(3)  - the expected HTTP status code
  #   ${4}  - the name of the variable that contains the thycotic response JSON
{
  msg "Error:  ${1}"
  msg "        The HTTP status code was: ${2}  (expected ${3})."
  if [ "${2}" == "400" ]; then
    msg "        The call failed due to an authentication error."
    call_catch_stdouterr "get_json_element_value .error ${4}"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      report_get_json_element_value_function_call_error_and_abort "${1}" "${catch_stdouterr__rc}" ".error" "${4}"
    else
      msg "        Thycotic error message: ${catch_stdouterr__stdout}"
    fi
  else
    msg "        The call failed due to an unknown error."
    msg "thycotic response json:"
    msg "----"
    msg "${!4}"
    msg "----"
  fi
  msg
  abort_script
}

get_thycotic_api_access_token()
{
  # If an existing access token exists, check its validity and if valid use it,
  # otherwise obtain a new access token.
  if [ -n "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
    # THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN has a non-empty value
    msg "THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN has a value - validating it..."
    validate_thycotic_api_access_token
  else
    msg "THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN does not have a value >>>${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}<<<"
  fi
  if [ -z "${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" ]; then
    # Either the exising access token was not valid, or none existed.
    # Obtain a new access token.
    get_user_username
    get_user_password
    call_catch_stdouterr "thycotic_authenticate_curl_command"
    thycotic_authenticate__response_json="${catch_stdouterr__stdout}"
    thycotic_authenticate__curl_information_json="${catch_stdouterr__stderr}"
    #msg "thycotic_authenticate__response_json is ${thycotic_authenticate__response_json}"
    #msg "thycotic_authenticate__curl_information_json is ${thycotic_authenticate__curl_information_json}"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to obtain an access token."
      msg "Message UUID: 64dd1032-b73f-441f-bfa0-f6c5fadece15"
      msg "The curl command to authenticate to Thycotic failed with return code: ${catch_stdouterr__rc}"
      call_catch_stdouterr "get_json_element_value .errormsg thycotic_authenticate__curl_information_json"
      if [ "${catch_stdouterr__rc}" -gt 0 ]; then
        msg "Failed to get the error message (errormsg element) from the curl information JSON."
        msg "get_json_element_value return code: ${catch_stdouterr__rc}"
        msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
        msg "The curl command error text is:"
        msg "${thycotic_authenticate__curl_information_json}"
      else
        msg "The curl error message: ${catch_stdouterr__stdout}"
      fi
      msg "\-----------------------------------------------------------"
      abort_script
    fi
    # Check that the HTTP status is 200
    call_catch_stdouterr "get_http_code_from_curl_information_json thycotic_authenticate__curl_information_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to obtain an access token."
      msg "Message UUID: 6501f01c-1007-44f9-851e-1a803aab2b09"
      msg "Failed to get the HTTP status code (http_code element) from the curl information JSON."
      msg "get_http_code_from_curl_information_json return code: ${catch_stdouterr__rc}"
      msg "get_http_code_from_curl_information_json error message: ${catch_stdouterr__stderr}"
      msg "The curl information JSON is:"
      msg "${thycotic_authenticate__curl_information_json}"
      msg "\-----------------------------------------------------------"
      abort_script
    fi
    curl__http_code="${catch_stdouterr__stdout}"
    if [ "${curl__http_code}" != "200" ]; then
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to obtain an access token."
      msg "Message UUID: 74a75572-692f-4e08-99eb-680763aadec0"
      msg "The HTTP status code for the authentication to Thycotic was: ${curl__http_code}  (expected 200)."
      call_catch_stdouterr "get_json_element_value .error thycotic_authenticate__response_json"
      if [ "${catch_stdouterr__rc}" -gt 0 ]; then
        msg "Failed to get the error message (error element) from the Thycotic authenticate response JSON."
        msg "Thycotic authenticate response JSON:"
        msg "${thycotic_authenticate__response_json}"
      else
        msg "Thycotic authenticate error message: ${catch_stdouterr__stdout}"
      fi
      msg "\-----------------------------------------------------------"
      abort_script
    fi
    # response is 200 OK
    #msg "thycotic authenticate response is 200 OK"

    # The check to ensure that the content_type is application/json is left out as the getting of
    # the access_token will either pass or fail depending on if the response is JSON or not.

    call_catch_stdouterr "get_json_element_value .access_token thycotic_authenticate__response_json"
    if [ "${catch_stdouterr__rc}" -ne 0 ]; then
      msg "/-----------------------------------------------------------"
      msg "Error: Failed to obtain an access token."
      msg "Message UUID: 66159660-5153-4a5c-b176-c50be01f68e6"
      msg "Failed to get the Access Token (access_token element) from the Thycotic authenticate response JSON."
      msg "get_json_element_value return code: ${catch_stdouterr__rc}"
      msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
      msg "Thycotic authenticate response JSON:"
      msg "${thycotic_authenticate__response_json}"
      msg "\-----------------------------------------------------------"
      abort_script
    fi
    THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN="${catch_stdouterr__stdout}"
  fi
}

get_user_username()
{
  THYCOTIC_USER_USERNAME=""
  if [ -n "${THYCOTIC_CLI_GET_USERNAME_COMMAND}" ]; then
    call_catch_stdouterr "${THYCOTIC_CLI_GET_USERNAME_COMMAND}"
    if [ "${catch_stdouterr__rc}" -ne 0 ]; then
      msg "/-----------------------------------------------------------"
      msg "Warning: The command contained in THYCOTIC_CLI_GET_USERNAME_COMMAND failed and won't be used."
      msg "Command return code was: ${catch_stdouterr__rc}"
      msg "Command error message: ${catch_stdouterr__stderr}"
      msg "\-----------------------------------------------------------"
      THYCOTIC_USER_USERNAME=""
    else
      THYCOTIC_USER_USERNAME="${catch_stdouterr__stdout}"
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
    call_catch_stdouterr "${THYCOTIC_CLI_GET_PASSWORD_COMMAND}"
    if [ "${catch_stdouterr__rc}" -ne 0 ]; then
      msg "/-----------------------------------------------------------"
      msg "Warning: The command contained in THYCOTIC_CLI_GET_PASSWORD_COMMAND failed and won't be used."
      msg "Command return code was: ${catch_stdouterr__rc}"
      msg "Command error message: ${catch_stdouterr__stderr}"
      msg "\-----------------------------------------------------------"
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

parse_json()
{
  jq '.' < <(echo ${parse_json_input})
}

get_curl_information_errormsg()
{
  jq -r '.errormsg' < <(echo ${curl_information_json})
}

get_http_code_from_curl_information_json()
  # Parameters:
  #   ${1}  - the name of the variable that contains the curl information JSON
  # Error return codes:
  #   1  - if parameter 1 does not have a value
  #   3  - if the http_code element could not be obtained from the curl information JSON
  #   4  - if the http_code element does not have a value
{
  if [ -z "${1}" ]; then
    echo "Error in get_http_code_from_curl_information_json - parameter 1 does not have a value" >&2
    return 1
  fi
  call_catch_stdouterr "get_json_element_value .http_code ${1}"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    echo "Error in get_http_code_from_curl_information_json - failed to get .http_code from curl information json." >&2
    echo "get_json_element_value return code: ${catch_stdouterr__rc}" >&2
    echo "get_json_element_value error message: ${catch_stdouterr__stderr}" >&2
    echo "The curl information json provided (named ${1}) was:" >&2
    echo "-------------------------------------" >&2
    echo "${!1}" >&2
    echo "-------------------------------------" >&2
    return 3
  fi
  http_code="${catch_stdouterr__stdout}"
  if [ -z "${http_code}" ]; then
    echo "Error in get_http_code_from_curl_information_json - the http_code from the curl information json was empty." >&2
    echo "The curl information json provided (named ${1}) was:" >&2
    echo "-------------------------------------" >&2
    echo "${!1}" >&2
    echo "-------------------------------------" >&2
    return 4
  fi
  echo "${http_code}"
  return 0
}

validate_thycotic_api_access_token()
{
  call_catch_stdouterr "thycotic_get_connection_manager_settings_curl_command"
  thycotic_get_connection_manager_settings__response_json="${catch_stdouterr__stdout}"
  thycotic_get_connection_manager_settings__curl_information_json="${catch_stdouterr__stderr}"
  msg "thycotic_get_connection_manager_settings__response_json is ${thycotic_get_connection_manager_settings__response_json}"
  msg "thycotic_get_connection_manager_settings__curl_information_json is ${thycotic_get_connection_manager_settings__curl_information_json}"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to check the validity of the Thycotic API Access Token."
    msg "Message UUID: 4f89664d-3474-4a9b-8081-1d26faace922"
    msg "The curl command to validate the Thycotic access token failed with return code: ${catch_stdouterr__rc}"
    call_catch_stdouterr "get_json_element_value .errormsg thycotic_get_connection_manager_settings__curl_information_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (errormsg element) from the curl information JSON."
      msg "get_json_element_value return code: ${catch_stdouterr__rc}"
      msg "get_json_element_value error message: ${catch_stdouterr__stderr}"
      msg "The curl command error text is:"
      msg "${thycotic_get_connection_manager_settings__curl_information_json}"
    else
      msg "The curl error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  # Check that the HTTP status is 200
  call_catch_stdouterr "get_http_code_from_curl_information_json thycotic_get_connection_manager_settings__curl_information_json"
  if [ "${catch_stdouterr__rc}" -gt 0 ]; then
    msg "/-----------------------------------------------------------"
    msg "Error: Failed to check the validity of the Thycotic API Access Token."
    msg "Message UUID: eefe6d0d-13da-47b6-852f-a2f34b0d1730"
    msg "Failed to get the HTTP status code (http_code element) from the curl information JSON."
    msg "get_http_code_from_curl_information_json return code: ${catch_stdouterr__rc}"
    msg "get_http_code_from_curl_information_json error message: ${catch_stdouterr__stderr}"
    msg "The curl information JSON is:"
    msg "${thycotic_get_connection_manager_settings__curl_information_json}"
    msg "\-----------------------------------------------------------"
    abort_script
  fi
  curl__http_code="${catch_stdouterr__stdout}"
  if [ "${curl__http_code}" != "200" ]; then
    msg "/-----------------------------------------------------------"
    msg "Warning: The provided Thycotic API Access Token is invalid or expired and won't be used. (See: thycotic_cli authenticate --help)"
    msg "Message UUID: 29d0ffda-8d2e-451b-982c-b5ecf563f6c1"
    msg "The HTTP status code for the token validation to Thycotic was: ${curl__http_code}  (expected 200)."
    call_catch_stdouterr "get_json_element_value .message thycotic_get_connection_manager_settings__response_json"
    if [ "${catch_stdouterr__rc}" -gt 0 ]; then
      msg "Failed to get the error message (message element) from the Thycotic token validation response JSON."
      msg "Thycotic token validation response JSON:"
      msg "${thycotic_get_connection_manager_settings__response_json}"
    else
      msg "Thycotic token validation error message: ${catch_stdouterr__stdout}"
    fi
    msg "\-----------------------------------------------------------"
    unset THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN
  fi
}

thycotic_authenticate_curl_command()
  # See:
  # https://thycotic.ad.adelaide.edu.au/RestApiDocs.ashx?doc=oauth-help#tag/Authentication/operation/OAuth2Service_Authorize
{
  curl --silent --write-out "%{stderr}%{json}" --header "Content-Type: application/x-www-form-urlencoded" --data @- --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/oauth2/token" < <(echo "grant_type=password&username=${THYCOTIC_USER_USERNAME}&password=${THYCOTIC_USER_PASSWORD}&organization=&domain=uofa")
}

thycotic_get_secret_curl_command()
  # See:
  # https://thycotic.ad.adelaide.edu.au/RestApiDocs.ashx?doc=Secrets#tag/Secrets/operation/SecretsService_GetSecretV2
{
  curl --silent --write-out "%{stderr}%{json}" -H "Authorization: Bearer ${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/api/v2/secrets/${THYCOTIC_CLI_SECRET_ID}"
}

thycotic_get_secret_field_curl_command()
  # See:
  # https://thycotic.ad.adelaide.edu.au/RestApiDocs.ashx?doc=Secrets#tag/Secrets/operation/SecretsService_GetField
{
  curl --silent --write-out "%{stderr}%{json}" -H "Authorization: Bearer ${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/api/v1/secrets/${THYCOTIC_CLI_SECRET_ID}/fields/${THYCOTIC_CLI_SECRET_FIELD_SLUG}"
}

thycotic_get_connection_manager_settings_curl_command()
  # See:
  # https://thycotic.ad.adelaide.edu.au/RestApiDocs.ashx?doc=ConnectionManagerSettings#tag/ConnectionManagerSettings/operation/ConnectionManagerSettingsService_Get
{
  curl --silent --write-out "%{stderr}%{json}" -H "Authorization: Bearer ${THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN}" --url "${THYCOTIC_CLI_THYCOTIC_HOST_URL}/api/v1/connection-manager-settings"
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
      --access_token=*)
        THYCOTIC_CLI_THYCOTIC_API_ACCESS_TOKEN="${1#*=}"
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

parse_script_params_get_secret()
{
  msg "script params (get_secret) (${#}) are: ${@}"
  # default values of variables set from params
  THYCOTIC_CLI_SECRET_ID=""
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      get_secret)
        shift
        break
        ;;
    esac
    shift
  done
  msg "script params (get_secret remainder) (${#}) are: ${@}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --secret_id=*)
        THYCOTIC_CLI_SECRET_ID="${1#*=}"
        ;;
      --help | -h)
        usage_get_secret
        exit
        ;;
      -?*)
        msg "Error: Unknown get_secret parameter: ${1}"
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
  msg "THYCOTIC_CLI_SECRET_ID: ${THYCOTIC_CLI_SECRET_ID}"
}

parse_script_params_get_secret_field_value()
{
  msg "script params (get_secret_field_value) (${#}) are: ${@}"
  # default values of variables set from params
  THYCOTIC_CLI_SECRET_ID=""
  THYCOTIC_CLI_SECRET_FIELD_SLUG=""
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      get_secret_field_value)
        shift
        break
        ;;
    esac
    shift
  done
  msg "script params (get_secret_field_value remainder) (${#}) are: ${@}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --secret_id=*)
        THYCOTIC_CLI_SECRET_ID="${1#*=}"
        ;;
      --field_slug=*)
        THYCOTIC_CLI_SECRET_FIELD_SLUG="${1#*=}"
        ;;
      --help | -h)
        usage_get_secret_field_value
        exit
        ;;
      -?*)
        msg "Error: Unknown get_secret_field_value parameter: ${1}"
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
  if [ -z "${THYCOTIC_CLI_SECRET_FIELD_SLUG}" ]; then
    msg "Error: Missing required parameter: field_slug"
    abort_script
  fi
  msg "THYCOTIC_CLI_SECRET_ID: ${THYCOTIC_CLI_SECRET_ID}"
  msg "THYCOTIC_CLI_SECRET_FIELD_SLUG: ${THYCOTIC_CLI_SECRET_FIELD_SLUG}"
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

call_catch_stdouterr()
  # Calls catch_stdouterr to call the function named in the first parameter.
  # Pre- and post- actions are called.
  # Result variables:
  #   - catch_stdouterr__rc       - the return code from the function call
  #   - catch_stdouterr__stdout   - the stdout from the function call
  #   - catch_stdouterr__stderr   - the stderr from the function call
{
  catch_stdouterr_pre_actions
  catch_stdouterr catch_stdouterr__stdout catch_stdouterr__stderr "${1}"
  catch_stdouterr__rc="$?"
  catch_stdouterr_post_actions
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
      THIS_SCRIPT_NAME="<script invoked via file descriptor (process substitution) and no default script name set>"
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
  echo >&2 "${THIS_SCRIPT_NAME} - aborting..."
  kill -SIGUSR1 ${THIS_SCRIPT_PROCESS_ID}
  exit
}

msg()
{
  echo >&2 -e "${@}"
}

# Main entry into the script - call the main() function
main "${@}"
