#!/bin/sh
# vim: syntax=sh:noexpandtab:sts=4:ts=4:sw=4

set -eux

OP_ADDR="${1:-""}"
OP_EMAIL="${2:-""}"

if [ -z "${OP_ADDR}" ] || [ -z "${OP_EMAIL}" ]; then
	printf 'Usage: %s op_hostname op_email\n' "${0}"
	exit 1
fi

cleanup() {
	if [ -d "${TEMPDIR}" ]; then
		/bin/rm -rf "${TEMPDIR}"
	fi

	trap - EXIT
}
trap cleanup EXIT INT TERM HUP

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

if [ "${OSTYPE}" = "darwin" ]; then
	if ! xcode-select --print-path >/dev/null 2>&1; then
		printf 'Installing XCode CLI tools\n'
		xcode-select --install >/dev/null 2>&1

		# Wait for xcode-select to be done
		until xcode-select --print-path >/dev/null 2>&1; do
			printf '.'
			sleep 5
		done
		print '\n'

		# Prompt to agree to license
		${SUDO_CMD} xcodebuild --license
	fi

	if [ ! -x /usr/local/bin/brew ]; then
		/bin/bash -c "$(${CURL_BIN} -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	fi

	/usr/local/bin/brew install ansible git
elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
	${SUDO_CMD} /usr/bin/dnf install --refresh -y ansible curl git-core libxml2 lsb unzip
elif [ -f /etc/arch-release ]; then
	${SUDO_CMD} /usr/bin/pacman -Sy --needed ansible curl git libxml2 unzip
elif [ "${OSTYPE}" = "openbsd" ]; then
	${SUDO_CMD} /usr/sbin/pkg_add -ru ansible curl git gnupg libxml unzip
fi

ANSIBLE_GALAXY_BIN="$(command -pv ansible-galaxy)"
if [ -z "${ANSIBLE_GALAXY_BIN}" ]; then
	printf 'Required tool ansible-galaxy not found\n'
	exit 1
fi

CHOWN_BIN="$(command -pv chown)"
if [ -z "${CHOWN_BIN}" ]; then
	printf 'Required tool chown not found\n' >&2
	exit 1
fi

CURL_BIN="$(command -pv curl)"
if [ -z "${CURL_BIN}" ]; then
	printf 'Required tool curl not found\n' >&2
	exit 1
fi

MKTEMP_BIN="$(command -pv mktemp)"
if [ -z "${MKTEMP_BIN}" ]; then
	printf 'Required tool mktemp not found\n' >&2
	exit 1
fi

TAR_BIN="$(command -pv tar)"
if [ -z "${TAR_BIN}" ]; then
	printf 'Required tool tar not found\n' >&2
	exit 1
fi

UNZIP_BIN="$(command -pv unzip)"
if [ -z "${UNZIP_BIN}" ]; then
	printf 'Required tool unzip not found\n' >&2
	exit 1
fi

XMLLINT_BIN="$(command -pv xmllint)"
if [ -z "${XMLLINT_BIN}" ]; then
	printf 'Required tool xmllint not found\n' >&2
	exit 1
fi

MACHINE="$("${UNAME_BIN}" -m)"
TEMPDIR="$("${MKTEMP_BIN}" -d XXXXXXXXXXXXXXXX)"

case "${MACHINE}" in
	x86_64)
		MACHINE="amd64"
		;;
	arm*)
		MACHINE="arm"
		;;
esac

${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" install kewlfft.aur
${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install community.general
${SUDO_CMD} "${ANSIBLE_GALAXY_BIN}" collection install community.postgresql

if [ "${OSTYPE}" = "openbsd" ] && [ ! -d /usr/ports ]; then
	${CURL_BIN} "https://cdn.openbsd.org/pub/OpenBSD/$("${UNAME_BIN}" -r)/ports.tar.gz" | ${SUDO_CMD} "${TAR_BIN}" zxphf - -C /usr
fi

if [ ! -f /usr/local/bin/op ]; then
	OP_URL="$(${CURL_BIN} -fsSL https://app-updates.agilebits.com/product_history/CLI 2>/dev/null | ${XMLLINT_BIN} --html --dtdattr --xpath "string(//article[not(@class='beta')][1]/div[@class='cli-archs']/p[@class='system ${OSTYPE}']/a[text()='${MACHINE}']/@href)" - 2>/dev/null)"
	${CURL_BIN} -fsSL "${OP_URL}" >"${TEMPDIR}/op.zip"

	if [ "${OSTYPE}" = "darwin" ]; then
		/bin/mv "${TEMPDIR}/op.zip" "${TEMPDIR}/op.pkg"
		${SUDO_CMD} /usr/sbin/installer -package "${TEMPDIR}/op.pkg" -target /
	else
		${UNZIP_BIN} "${TEMPDIR}/op.zip" op
		${SUDO_CMD} /bin/mv ./op /usr/local/bin/op
	fi
fi

eval "$(/usr/local/bin/op signin "${OP_ADDR}" "${OP_EMAIL}")"

if [ ! -d "${HOME}/.ssh" ]; then
	/bin/mkdir "${HOME}/.ssh"
	/bin/chmod 0700 "${HOME}/.ssh"
fi
/usr/local/bin/op get document g5e5zo2sgpkwum6npqbt6l7ari >"${HOME}/.ssh/github"
/bin/chmod 0600 "${HOME}"/.ssh/*
/usr/bin/ssh-keygen -y -f "${HOME}/.ssh/github" >"${HOME}/.ssh/github.pub"

/usr/local/bin/op get document qukaq3aej2hftq6t2ojuwvpm6m | gpg --import

$(command -v git) config filter.crypt.required ''
$(command -v git) config filter.crypt.clean 'gpg -sea -r E9F9F8EA7E062F78 -u E9F9F8EA7E062F78 -o -'
$(command -v git) config filter.crypt.smudge 'gpg -d -o -'

/usr/bin/ssh-agent /bin/sh -c "/usr/bin/ssh-add \"${HOME}/.ssh/github\"; $(command -v git) clone git@github.com:jgoguen/ansible_playbooks.git"
${SUDO_CMD} /bin/mv ansible_playbooks /var/

cd /var/ansible_playbooks
${SUDO_CMD} "$(command -v ansible-playbook)" -i inventory hosts.yml --diff
