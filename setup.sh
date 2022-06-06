#!/bin/sh
# vim: set autoindent foldmarker=[[[,]]] foldmethod=marker foldlevel=0:

set -eux

# 1Password hostname and email as parameters [[[
OP_ADDR="${1:-""}"
OP_EMAIL="${2:-""}"

if [ -n "${OP_ADDR}" ]; then
	shift
fi
if [ -n "${OP_EMAIL}" ]; then
	shift
fi

while [ -z "${OP_ADDR}" ]; do
	printf '1Password hostname: '
	read -r OP_ADDR
done
while [ -z "${OP_EMAIL}" ]; do
	printf '1Password email: '
	read -r OP_EMAIL
done
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

TEMPDIR="$(mktemp -d XXXXXXXXXXXXXXXX)"

# Install the OpenBSD ports tree if needed [[[
if [ "${OSTYPE}" = "openbsd" ] && [ ! -d /usr/ports ]; then
	curl "https://cdn.openbsd.org/pub/OpenBSD/$("${UNAME_BIN}" -r)/ports.tar.gz" | ${SUDO_CMD} tar zxphf - -C /usr
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
	OP_URL="$(curl -fsSL https://app-updates.agilebits.com/product_history/CLI2 2>/dev/null | xmllint --html --dtdattr --xpath "string(//article[not(@class='beta')][1]/div[@class='cli-archs']/p[@class='system ${OS_ATTR}']/a[text()='${MACHINE_ATTR}']/@href)" - 2>/dev/null)"
	curl -fsSL "${OP_URL}" >"${TEMPDIR}/op.zip"

	if [ "${OSTYPE}" = "darwin" ]; then
		/bin/mv "${TEMPDIR}/op.zip" "${TEMPDIR}/op.pkg"
		${SUDO_CMD} /usr/sbin/installer -package "${TEMPDIR}/op.pkg" -target /
	else
		unzip "${TEMPDIR}/op.zip" op
		${SUDO_CMD} /bin/mv ./op /usr/local/bin/op
	fi
fi
# ]]]

eval "$(/usr/local/bin/op account add --signin --address "${OP_ADDR}" --email "${OP_EMAIL}")"
/usr/local/bin/op document get qukaq3aej2hftq6t2ojuwvpm6m | gpg --import
printf '75E259BA34917C792560A53AE9F9F8EA7E062F78:6:' | gpg --import-ownertrust

if [ ! -d /var/ansible_playbooks ]; then
	git clone --depth 1 https://github.com/jgoguen/ansible_playbooks.git
	${SUDO_CMD} /bin/mv ansible_playbooks /var/
	cd /var/ansible_playbooks
	git-crypt unlock
fi

/bin/sh /var/ansible_playbooks/run_ansible.sh "$@"
