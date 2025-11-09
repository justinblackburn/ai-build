#!/bin/bash
# populate-git-cache.sh - Clone git repositories for Vagrant offline usage
# Run this script from the host machine to cache git repos in files/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "======================================================================"
echo "  Git Repository Cache Population Script"
echo "======================================================================"
echo ""
echo "This script will clone git repositories to: ${SCRIPT_DIR}"
echo "These repos will be available to your Vagrant VM at /mnt/files"
echo ""

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "ERROR: git not found. Please install git first."
    exit 1
fi

echo "Using: $(git --version)"
echo ""

# Function to clone or update repos
clone_or_update() {
    local repo_url="$1"
    local repo_name="$2"
    local description="$3"

    echo "----------------------------------------------------------------------"
    echo "Repository: ${description}"
    echo "----------------------------------------------------------------------"

    if [ -d "${repo_name}/.git" ]; then
        echo "Repository already exists. Updating..."
        cd "${repo_name}"
        git fetch origin
        git pull origin master 2>/dev/null || git pull origin main 2>/dev/null || echo "Pull skipped"
        cd ..
    else
        echo "Cloning ${repo_url}..."
        git clone "${repo_url}" "${repo_name}"
    fi

    echo "✓ ${description} cached"
    echo ""
}

# Prompt for what to download
echo "Select components to cache:"
echo ""
echo "  1) All components (Stable Diffusion + ComfyUI + xformers)"
echo "  2) Stable Diffusion only"
echo "  3) ComfyUI only"
echo "  4) xformers only"
echo "  5) Custom (select individual components)"
echo ""
read -p "Enter choice [1-5]: " choice

cache_sd=false
cache_comfy=false
cache_xformers=false

case $choice in
    1)
        cache_sd=true
        cache_comfy=true
        cache_xformers=true
        ;;
    2)
        cache_sd=true
        ;;
    3)
        cache_comfy=true
        ;;
    4)
        cache_xformers=true
        ;;
    5)
        read -p "Cache Stable Diffusion (AUTOMATIC1111)? [y/N]: " sd_choice
        [[ "${sd_choice,,}" == "y" ]] && cache_sd=true

        read -p "Cache ComfyUI? [y/N]: " comfy_choice
        [[ "${comfy_choice,,}" == "y" ]] && cache_comfy=true

        read -p "Cache xformers? [y/N]: " xformers_choice
        [[ "${xformers_choice,,}" == "y" ]] && cache_xformers=true
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "======================================================================"
echo "  Starting Git Clones"
echo "======================================================================"
echo ""

# Clone repositories
if [[ "${cache_sd}" == "true" ]]; then
    clone_or_update \
        "https://github.com/AUTOMATIC1111/stable-diffusion-webui.git" \
        "stable-diffusion-webui" \
        "AUTOMATIC1111 Stable Diffusion WebUI"
fi

if [[ "${cache_comfy}" == "true" ]]; then
    clone_or_update \
        "https://github.com/comfyanonymous/ComfyUI.git" \
        "ComfyUI" \
        "ComfyUI"
fi

if [[ "${cache_xformers}" == "true" ]]; then
    clone_or_update \
        "https://github.com/facebookresearch/xformers.git" \
        "xformers" \
        "Facebook Research xformers"
fi

echo "======================================================================"
echo "  Caching Complete!"
echo "======================================================================"
echo ""
echo "Cached repositories location: ${SCRIPT_DIR}"
echo ""

# Show summary
REPO_COUNT=$(find "${SCRIPT_DIR}" -maxdepth 1 -type d -name ".git" -o -type d -path "*/.git" | wc -l)
CACHE_SIZE=$(du -sh "${SCRIPT_DIR}" 2>/dev/null | cut -f1 || echo "unknown")

echo "Summary:"
echo "  - Total repositories: ${REPO_COUNT}"
echo "  - Cache size: ${CACHE_SIZE}"
echo ""
echo "These repositories are now available to your Vagrant VM at:"
echo "  - /mnt/files/"
echo ""
echo "Next steps:"
echo "  1. Reload your Vagrant VM to mount /mnt/files:"
echo "     cd vagrant/rhel9 && vagrant reload"
echo "  2. Run playbooks normally - they will use local repos automatically"
echo ""
echo "======================================================================"
