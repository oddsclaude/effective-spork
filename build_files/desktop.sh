#!/usr/bin/env bash
#   /run/context/build_files/desktop.sh <desktop>

set -xeuo pipefail

DESKTOP="${1:?Usage: desktop.sh <desktop>}"

case "${DESKTOP}" in
hyprland)
	pacman -S --noconfirm --needed \
		hyprland \
		hypridle \
		hyprlock \
		hyprpaper \
		xdg-desktop-portal-hyprland \
		waybar \
		greetd \
		greetd-tuigreet \
		kitty \
		polkit-gnome \
		qt5-wayland \
		qt6-wayland

	systemctl enable greetd.service
	systemctl set-default graphical.target
	;;
*)
	echo "ERROR: unknown desktop '${DESKTOP}'" >&2
	exit 1
	;;
esac

# ── NVIDIA ────────────────────────────────────────────────────────────────────
# ENABLE_NVIDIA is declared as an ARG/ENV on the base stage in
# Containerfile.arch and inherited here.
if [[ "${ENABLE_NVIDIA:-0}" == "1" ]]; then
	echo "ENABLE_NVIDIA=1 — installing nvidia driver stack"
	pacman -S --noconfirm --needed \
		nvidia-open-dkms \
		nvidia-utils \
		nvidia-settings \
		lib32-nvidia-utils \
		egl-wayland \
		vulkan-icd-loader \
		lib32-vulkan-icd-loader

# install-desktop.sh — Arch/pacman-only desktop installer driven by YAML manifests.
#
# Stripped from the original multi-distro version (apt/zypper/emerge/dnf paths
# removed) since this image only ever builds on Arch. Adds ENABLE_NVIDIA
# handling, which the upstream script declared as a Containerfile ARG/ENV but
# never actually consumed anywhere.
#
# Reads a desktop manifest from manifests/desktops/<desktop>.yaml (or
# <desktop>-arch.yaml if present) and installs packages, enables the display
# manager, applies post-install hooks, and (if ENABLE_NVIDIA=1) installs the
# nvidia driver stack for the desktop's session type.
#
# Usage:
#   /run/context/build_scripts/desktop/install-desktop.sh <desktop>
#
# Requires yq (mikefarah/yq) available at YQ env var or in PATH.

set -xeuo pipefail

_TD_DESKTOP="${1:?Usage: install-desktop.sh <desktop>}"
_TD_CTX="/run/context"

# lib.sh first: manifest resolution below needs PKG_MGR.
source "${_TD_CTX}/build_scripts/lib.sh"

# <desktop>-arch.yaml beats the generic <desktop>.yaml when present — package
# names, session files, and display managers can differ from the generic
# manifest (e.g. a desktop that needs a CachyOS-specific tweak).
_TD_MANIFEST="${_TD_CTX}/manifests/desktops/${_TD_DESKTOP}.yaml"
if [[ -f "${_TD_CTX}/manifests/desktops/${_TD_DESKTOP}-arch.yaml" ]]; then
	_TD_MANIFEST="${_TD_CTX}/manifests/desktops/${_TD_DESKTOP}-arch.yaml"
fi

if [[ ! -f "${_TD_MANIFEST}" ]]; then
	echo "ERROR: No manifest found at ${_TD_MANIFEST}" >&2
	echo "Available desktops:"
	ls "${_TD_CTX}/manifests/desktops/"*.yaml 2>/dev/null | sed 's|.*/||;s|\.yaml||'
	exit 1
fi

# Ensure yq is available inside the container for manifest parsing.
YQ="${YQ:-yq}"
if ! command -v "$YQ" &>/dev/null; then
	YQ_ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
	curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.53.3/yq_linux_${YQ_ARCH}" -o /usr/bin/yq
	chmod +x /usr/bin/yq
	YQ=/usr/bin/yq
fi
printf "::group:: === install-desktop: %s ===\n" "${_TD_DESKTOP}"

# Check for CachyOS-specific section (Arch derivative with extra repos)
_TD_CACHYOS=""
if [[ -f /etc/cachyos-release ]]; then
	_TD_CACHYOS="cachyos"
fi

echo "Installing ${_TD_DESKTOP} desktop..."

# ── Pacman path ───────────────────────────────────────────────────────────────
if [[ -n "${_TD_CACHYOS}" ]]; then
	_TD_REPO_COUNT=$($YQ -r ".packages.${_TD_CACHYOS}.repos | length // 0" "${_TD_MANIFEST}" 2>/dev/null)
	for ((i = 0; i < _TD_REPO_COUNT; i++)); do
		_TD_REPO_NAME=$($YQ -r ".packages.${_TD_CACHYOS}.repos[$i].name" "${_TD_MANIFEST}")
		_TD_REPO_URL=$($YQ -r ".packages.${_TD_CACHYOS}.repos[$i].url" "${_TD_MANIFEST}")
		if ! grep -q "\\[${_TD_REPO_NAME}\\]" /etc/pacman.conf; then
			printf '\n[%s]\nServer = %s\n' "${_TD_REPO_NAME}" "${_TD_REPO_URL}" >>/etc/pacman.conf
		fi
	done
	pacman -Sy --noconfirm
	readarray -t _TD_CACHY_PKGS < <($YQ -r ".packages.${_TD_CACHYOS}.packages[]" "${_TD_MANIFEST}" 2>/dev/null || true)
	if ((${#_TD_CACHY_PKGS[@]} > 0)); then
		pacman -S --noconfirm --needed "${_TD_CACHY_PKGS[@]}"
	fi
fi

readarray -t _TD_PKGS < <($YQ -r ".packages.pacman[]" "${_TD_MANIFEST}" 2>/dev/null || true)
if ((${#_TD_PKGS[@]} == 0)); then
	echo "ERROR: ${_TD_MANIFEST} has no .packages.pacman list." >&2
	echo "       Installing no packages would yield an image tagged" >&2
	echo "       '${_TD_DESKTOP}' with no desktop in it." >&2
	exit 1
fi
pacman -S --noconfirm --needed "${_TD_PKGS[@]}"

if [[ "${ENABLE_NVIDIA:-0}" == "1" ]]; then
	echo "ENABLE_NVIDIA=1 — installing nvidia driver stack"
	_TD_NVIDIA_PKGS=(
		nvidia-open-dkms   # open-source kernel modules; swap for `nvidia-dkms` if closed-source is required
		nvidia-utils
		nvidia-settings
		lib32-nvidia-utils # 32-bit compat for Steam/Wine/etc
		egl-wayland        # GLVND EGL vendor for Wayland compositors (hyprland, niri)
		vulkan-icd-loader
		lib32-vulkan-icd-loader
	)
	pacman -S --noconfirm --needed "${_TD_NVIDIA_PKGS[@]}"

	if pacman -Qq linux-cachyos &>/dev/null; then
		pacman -S --noconfirm --needed linux-cachyos-headers
	else
		pacman -S --noconfirm --needed linux-headers
	fi

	mkdir -p /usr/lib/dracut/dracut.conf.d/
	printf 'add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "\n' \
		> /usr/lib/dracut/dracut.conf.d/30-nvidia-kms.conf
	printf 'options nvidia_drm modeset=1 fbdev=1\n' \
		> /etc/modprobe.d/nvidia.conf

	mkdir -p /etc/environment.d
	printf 'LIBVA_DRIVER_NAME=nvidia\nGBM_BACKEND=nvidia-drm\n__GLX_VENDOR_LIBRARY_NAME=nvidia\n' \
		> /etc/environment.d/10-nvidia.conf
fi
# Enable display manager
_TD_DM=$($YQ -r '.display_manager' "${_TD_MANIFEST}")
if [[ -n "${_TD_DM}" && "${_TD_DM}" != "null" ]]; then
	# Not `|| true`: a manifest naming a DM the package set didn't provide
	# means the package list is wrong, not that enabling should be skipped.
	systemctl enable "${_TD_DM}"
	systemctl set-default graphical.target
fi
printf "::endgroup::\n"

# ── Disable desktop files ────────────────────────────────────────────────────
readarray -t _TD_DISABLE < <($YQ -r '.disable_desktop_files[]' "${_TD_MANIFEST}" 2>/dev/null || true)
for df in "${_TD_DISABLE[@]}"; do
	if [[ -n "$df" && -f "/usr/share/applications/${df}" ]]; then
		mv "/usr/share/applications/${df}" "/usr/share/applications/${df}.disabled"
	fi
done

# ── Post-install scripts ─────────────────────────────────────────────────────
readarray -t _TD_POST_SCRIPTS < <($YQ -r '.post_install[]' "${_TD_MANIFEST}" 2>/dev/null || true)
for script in "${_TD_POST_SCRIPTS[@]}"; do
	if [[ -n "$script" && -f "${_TD_CTX}/build_scripts/desktop/${script}" ]]; then
		echo "Running post-install: ${script}"
		source "${_TD_CTX}/build_scripts/desktop/${script}"
	fi
done

# Inline post-install commands
readarray -t _TD_POST_INLINE < <($YQ -r '.post_install_inline[]' "${_TD_MANIFEST}" 2>/dev/null || true)
for cmd in "${_TD_POST_INLINE[@]}"; do
	if [[ -n "$cmd" ]]; then
		eval "$cmd"
	fi
done

# Desktop communities own their curated defaults as plain files.
_TD_EXPERIENCE_FILES="${_TD_CTX}/experiences/${_TD_DESKTOP}/files"
if [[ -d "${_TD_EXPERIENCE_FILES}" ]]; then
	echo "Applying curated ${_TD_DESKTOP} experience defaults"
	cp -a "${_TD_EXPERIENCE_FILES}/." /
fi

# A package transaction is not sufficient evidence that the requested desktop
# exists. Validate its session, compositor and display manager, then install
# a runtime contract checked by the VM promotion gate.
if [[ -x "${_TD_CTX}/build_scripts/checks/verify-desktop-experience.sh" ]]; then
	"${_TD_CTX}/build_scripts/checks/verify-desktop-experience.sh" "${_TD_DESKTOP}"
	install -Dm0755 "${_TD_CTX}/build_scripts/checks/verify-desktop-experience.sh" \
		/usr/libexec/tunaos/verify-desktop-experience
	install -Dm0755 "${_TD_CTX}/build_scripts/checks/e2e-runtime-checks.sh" \
		/usr/libexec/tunaos/e2e-runtime-checks
	cat >/usr/lib/systemd/system/tunaos-desktop-contract.service <<EOF
[Unit]
Description=Verify TunaOS ${_TD_DESKTOP} desktop experience
After=display-manager.service
Requires=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/libexec/tunaos/verify-desktop-experience ${_TD_DESKTOP} --runtime
ExecStart=-/usr/libexec/tunaos/e2e-runtime-checks ${_TD_DESKTOP}
StandardOutput=journal+console
StandardError=journal+console
TimeoutStartSec=90

[Install]
WantedBy=graphical.target
EOF
	safe_enable tunaos-desktop-contract.service
fi

printf "::endgroup::\n"
