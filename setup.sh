#!/bin/sh
# vim: set noexpandtab tabstop=2 shiftwidth=2 autoindent:
# vim: set foldmarker=[[[,]]] foldmethod=marker foldlevel=0:

set -eux

# 1Password hostname and email as parameters [[[
OP_ADDR="${1:-""}"
OP_EMAIL="${2:-""}"

if [ -z "${OP_ADDR}" ] || [ -z "${OP_EMAIL}" ]; then
	printf 'Usage: %s 1password_hostname 1password_email [--check]\n' "${0}" >&2
	exit 1
fi
shift 2
# ]]]

# Define cleanup on script exit or termination [[[
cleanup() {
	if [ -d "${TEMPDIR}" ]; then
		/bin/rm -rf "${TEMPDIR}"
	fi

	if [ -f "${CHEZMOI_FILTER_FILE:-/.does_not_exist}" ]; then
		/bin/rm -f "${CHEZMOI_FILTER_FILE}"
	fi

	trap - EXIT
}
trap cleanup EXIT INT TERM HUP
# ]]]

# Determine machine architecture and OS type [[[
UNAME_BIN="$(command -pv uname)"
if [ -z "${UNAME_BIN}" ]; then
	printf 'Required tool uname not found\n' >&2
	exit 1
fi

MACHINE="$("${UNAME_BIN}" -m)"
case "${MACHINE}" in
	x86_64)
		MACHINE="amd64"
		HOMEBREW_BIN="/usr/local/bin/brew"
		;;
	arm*)
		MACHINE="arm"
		HOMEBREW_BIN="/opt/homebrew/bin/brew"
		;;
	aarch64)
		MACHINE="arm64"
		HOMEBREW_BIN="/opt/homebrew/bin/brew"
		;;
esac

OSTYPE="$("${UNAME_BIN}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
if [ "${OSTYPE}" = "openbsd" ]; then
	SUDO_CMD=/usr/bin/doas
else
	SUDO_CMD=/usr/bin/sudo
fi
# ]]]

# Install packages required for setup [[[
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
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	fi

	${HOMEBREW_BIN} install ansible git git-crypt
elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
	${SUDO_CMD} /usr/bin/dnf install --refresh -y ansible curl git-core \
		git-crypt gnupg2 libxml2 lsb unzip
elif [ -f /etc/debian_version ]; then
	${SUDO_CMD} /usr/bin/apt install -y ansible curl git git-crypt gnupg2 \
		libxml2-utils lsb-release unzip
elif [ "${OSTYPE}" = "openbsd" ]; then
	${SUDO_CMD} /usr/sbin/pkg_add -ru ansible curl git git-crypt gnupg--%gnupg2 \
		libxml unzip--
fi
# ]]]

# Locate other tools on the system [[[
ANSIBLE_GALAXY_BIN="$(command -v ansible-galaxy)"
if [ -z "${ANSIBLE_GALAXY_BIN}" ]; then
	printf 'Required tool ansible-galaxy not found\n'
	exit 1
fi

CHOWN_BIN="$(command -v chown)"
if [ -z "${CHOWN_BIN}" ]; then
	printf 'Required tool chown not found\n' >&2
	exit 1
fi

CURL_BIN="$(command -v curl)"
if [ -z "${CURL_BIN}" ]; then
	printf 'Required tool curl not found\n' >&2
	exit 1
fi

GPG_BIN="$(command -v gpg)"
if [ -z "${GPG_BIN}" ]; then
	printf 'Required tool gpg not found\n' >&2
	exit 1
fi

MKTEMP_BIN="$(command -v mktemp)"
if [ -z "${MKTEMP_BIN}" ]; then
	printf 'Required tool mktemp not found\n' >&2
	exit 1
fi

TAR_BIN="$(command -v tar)"
if [ -z "${TAR_BIN}" ]; then
	printf 'Required tool tar not found\n' >&2
	exit 1
fi

UNZIP_BIN="$(command -v unzip)"
if [ -z "${UNZIP_BIN}" ]; then
	printf 'Required tool unzip not found\n' >&2
	exit 1
fi

XMLLINT_BIN="$(command -v xmllint)"
if [ -z "${XMLLINT_BIN}" ]; then
	printf 'Required tool xmllint not found\n' >&2
	exit 1
fi
# ]]]

TEMPDIR="$("${MKTEMP_BIN}" -d XXXXXXXXXXXXXXXX)"

# Install the OpenBSD ports tree if needed [[[
if [ "${OSTYPE}" = "openbsd" ] && [ ! -d /usr/ports ]; then
	${CURL_BIN} "https://cdn.openbsd.org/pub/OpenBSD/$("${UNAME_BIN}" -r)/ports.tar.gz" | ${SUDO_CMD} "${TAR_BIN}" zxphf - -C /usr
fi
# ]]]

# Fetch the op CLI from upstream and install it [[[
# This is janky as fuck screen-scraping to get the package URL, here's hoping
# AgileBits doesn't decide to make minor changes to the page!
if [ ! -f /usr/local/bin/op ]; then
	if [ "${OSTYPE}" = "darwin" ]; then
		OS_ATTR="apple"
		MACHINE_ATTR="universal"
	else
		OS_ATTR="${OSTYPE}"
		MACHINE_ATTR="${MACHINE}"
	fi
	OP_URL="$(${CURL_BIN} -fsSL https://app-updates.agilebits.com/product_history/CLI 2>/dev/null | ${XMLLINT_BIN} --html --dtdattr --xpath "string(//article[not(@class='beta')][1]/div[@class='cli-archs']/p[@class='system ${OS_ATTR}']/a[text()='${MACHINE_ATTR}']/@href)" - 2>/dev/null)"
	${CURL_BIN} -fsSL "${OP_URL}" >"${TEMPDIR}/op.zip"

	if [ "${OSTYPE}" = "darwin" ]; then
		/bin/mv "${TEMPDIR}/op.zip" "${TEMPDIR}/op.pkg"
		${SUDO_CMD} /usr/sbin/installer -package "${TEMPDIR}/op.pkg" -target /
	else
		${UNZIP_BIN} "${TEMPDIR}/op.zip" op
		${SUDO_CMD} /bin/mv ./op /usr/local/bin/op
	fi
fi
# ]]]

eval "$(/usr/local/bin/op signin "${OP_ADDR}" "${OP_EMAIL}")"

/usr/local/bin/op get document qukaq3aej2hftq6t2ojuwvpm6m | ${GPG_BIN} --import

if [ ! -d /var/ansible_playbooks ]; then
	$(command -v git) clone --depth 1 https://github.com/jgoguen/ansible_playbooks.git
	${SUDO_CMD} /bin/mv ansible_playbooks /var/
	cd /var/ansible_playbooks
	$(command -v git-crypt) unlock
fi

/bin/sh /var/ansible_playbooks/run_ansible.sh "$@"
