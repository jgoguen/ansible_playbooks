#!/bin/sh
# vim: syntax=sh:noexpandtab:sts=4:ts=4:sw=4

set -eux

UNAME_BIN="$(command -pv uname)"
if [ -z "${UNAME_BIN}" ]; then
	printf 'Required tool uname not found\n' >&2
	exit 1
fi

OSTYPE="$("${UNAME_BIN}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
if [ "${OSTYPE}" = "openbsd" ]; then
	SUDO_CMD=/usr/bin/doas
else
	SUDO_CMD=/usr/bin/sudo
fi

ANSIBLE_GALAXY_BIN="$(command -pv ansible-galaxy)"
if [ -z "${ANSIBLE_GALAXY_BIN}" ]; then
	printf 'Required tool ansible-galaxy not found\n'
	exit 1
fi

${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install ansible.posix
${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install kewlfft.aur
${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install community.general
${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install community.postgresql

cd "$(dirname "${0}")" || exit 1
${SUDO_CMD} "$(command -v ansible-playbook)" -i inventory hosts.yml --diff "$@"
