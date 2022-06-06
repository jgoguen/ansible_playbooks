#!/bin/sh
# vim: set autoindent foldmarker=[[[,]]] foldmethod=marker foldlevel=0:

set -ux

OSTYPE="$(uname | /usr/bin/tr '[:upper:]' '[:lower:]')"
if [ "${OSTYPE}" = "openbsd" ]; then
	SUDO_CMD=/usr/bin/doas
else
	SUDO_CMD=/usr/bin/sudo
fi

if [ "${OSTYPE}" = "darwin" ]; then
	ROOT_HOME="$(${SUDO_CMD} /usr/bin/dscl . -read /Users/root NFSHomeDirectory | /usr/bin/awk '{print $NF}')"
else
	ROOT_HOME="$(/usr/bin/getent passwd root | /usr/bin/cut -d ':' -f 6)"
fi
for collection in ansible.posix community.docker community.general community.postgresql; do
	${SUDO_CMD} test -d "${ROOT_HOME}/.ansible/collections/ansible_collections/$(printf '%s' "${collection}" | tr '.' '/')"; rv=$?
	if [ "${rv}" -ne 0 ]; then
		${SUDO_CMD} ansible-galaxy collection install "${collection}"
	fi
done

cd "$(dirname "${0}")" || exit 1
${SUDO_CMD} ansible-playbook -i inventory hosts.yml --become-method "$(basename ${SUDO_CMD})" --diff "$@"
