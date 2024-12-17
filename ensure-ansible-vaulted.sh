#!/usr/bin/env bash
# -*- coding: utf-8 -*-

#
# (c) 2023, Andrew Sichevoi https://thekondor.net
#

CONFIG_FILENAME=.ensure-ansiblevaulted.yml
REPO_DIR="${PWD}"
SELF_CFG="${REPO_DIR}/${CONFIG_FILENAME}"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
SELF_NAME="$(basename "$0")"
SELF_EDITOR="${SELF_DIR}/${SELF_NAME}"

_ERR="❌ error"
_INF="❇️"

### ansible-vault's mutation operations are done through $EDITOR. Since our goal to avoid interactive edit
### and pipe the contents in, we replace $EDITOR with "very own" implementation
if [ "$EDITOR" = "${SELF_EDITOR}" ]; then
  cat >"$1"
  exit $?
fi

if ! which yq 1>/dev/null; then
  echo "- ${_ERR}: yq is not installed"
  exit 1
fi

if ! which ansible-vault 1>/dev/null; then
  echo "- ${_ERR}: ansible-vault is either not installed or not within virtualenv"
  exit 1
fi

if [ ! -f "${SELF_CFG}" ]; then
  echo "- ${_ERR}: configuration file ${CONFIG_FILENAME} is mandatory"
  exit 1
fi

if ! OPT_ENCRYPTED_EXT=$(yq '.encrypted-extension // "enc.yaml"' "${SELF_CFG}"); then
  echo "- ${_ERR}: config error while reading encrypted extension"
  exit 1
fi

OPT_VAULT_PASSWORD_FILE=$(yq '.vault-password-file // ""' "${SELF_CFG}")
ANSIBLE_VAULT_PASSWORD_ARG=""
if [ -n "${OPT_VAULT_PASSWORD_FILE}" ]; then
  ANSIBLE_VAULT_PASSWORD_ARG="--vault-password-file ${OPT_VAULT_PASSWORD_FILE}"
fi

OPT_ENSURE_IGNORED=$(yq '.track-git-ignored // ".with-error"' "${SELF_CFG}")
if [ ! ".with-error" = "${OPT_ENSURE_IGNORED}" ] && [ ! ".with-warning" = "${OPT_ENSURE_IGNORED}" ]; then
  echo " - ${_ERR}: unknown value for track-ignored=${OPT_ENSURE_IGNORED}"
  exit 1
fi

export EDITOR="${SELF_EDITOR}"

while read -r PLAIN_ENTRY; do
  while read -r PLAIN_FULL_PATH; do
    ENCRYPTED_FULL_PATH="${PLAIN_FULL_PATH%.*}.${OPT_ENCRYPTED_EXT}"

    echo "- ${_INF} ensure ansible vaulted: ${PLAIN_FULL_PATH} -> ${ENCRYPTED_FULL_PATH}"

    if [ ! -f "${PLAIN_FULL_PATH}" ]; then
      echo "  + ${_ERR}: ${PLAIN_FULL_PATH} not found/accessible"
      exit 1
    fi

    if ! git check-ignore -q "${PLAIN_FULL_PATH}"; then
      echo "  + ${PLAIN_FULL_PATH} is not declared in .gitignore"
      if [ ".with-error" = "${OPT_ENSURE_IGNORED}" ]; then
        echo "  + ${_ERR}: this is critical"
        exit 1
      fi
    fi

    if [ ! -f "${ENCRYPTED_FULL_PATH}" ]; then
      echo "  + ${ENCRYPTED_FULL_PATH} not found, creating for you..."
      # shellcheck disable=SC2086
      if ! ansible-vault create --skip-tty-check ${ANSIBLE_VAULT_PASSWORD_ARG} "${ENCRYPTED_FULL_PATH}" <"${PLAIN_FULL_PATH}"; then
        echo "  + ${_ERR}: failed"
        exit 1
      fi
    else
      # shellcheck disable=SC2086
      diff <(cat "${PLAIN_FULL_PATH}") <(ansible-vault view ${ANSIBLE_VAULT_PASSWORD_ARG} "${ENCRYPTED_FULL_PATH}") >/dev/null 2>&1
      # shellcheck disable=SC2181
      if [ 0 -eq $? ]; then
        echo "  + ${_INF} no changes, skipping"
        continue
      fi
    fi

    echo "  ! ${_INF} There is a difference. Contents to be replaced."

    # shellcheck disable=SC2086
    if ! ansible-vault edit ${ANSIBLE_VAULT_PASSWORD_ARG} "${ENCRYPTED_FULL_PATH}" <"${PLAIN_FULL_PATH}"; then
      echo "  ${_ERR}: Update failed"
      exit 1
    fi

    echo "ansible-vaulted[to-add]:${ENCRYPTED_FULL_PATH}"
  done < <(find "${REPO_DIR}" -type f -name "${PLAIN_ENTRY}")
done < <(yq '.files[]' "${SELF_CFG}")
