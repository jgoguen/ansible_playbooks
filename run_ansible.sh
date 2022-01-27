#!/bin/sh
# vim: set noexpandtab:

set -ux

UNAME_BIN="$(command -v uname)"
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

ANSIBLE_GALAXY_BIN="$(command -v ansible-galaxy)"
if [ -z "${ANSIBLE_GALAXY_BIN}" ]; then
	printf 'Required tool ansible-galaxy not found\n'
	exit 1
fi

if [ "${OSTYPE}" = "darwin" ]; then
	ROOT_HOME="$(${SUDO_CMD} /usr/bin/dscl . -read /Users/root NFSHomeDirectory | /usr/bin/awk '{print $NF}')"
else
	ROOT_HOME="$(/usr/bin/getent passwd root | /usr/bin/cut -d ':' -f 6)"
fi
for collection in ansible.posix kewlfft.aur community.general community.postgresql; do
	${SUDO_CMD} test -d "${ROOT_HOME}/.ansible/collections/ansible_collections/$(printf '%s' "${collection}" | tr '.' '/')"; rv=$?
	if [ "${rv}" -ne 0 ]; then
		${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install "${collection}"
	fi
done

cd "$(dirname "${0}")" || exit 1
${SUDO_CMD} "$(command -v ansible-playbook)" -i inventory hosts.yml --become-method "$(basename ${SUDO_CMD})" --diff "$@"
