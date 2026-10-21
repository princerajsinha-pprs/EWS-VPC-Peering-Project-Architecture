#!/usr/bin/env bash
# Shared settings and helpers. Sourced by every script.
set -euo pipefail

export AWS_REGION="${AWS_REGION:-ap-south-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
AZ="${AZ:-${AWS_REGION}a}"
STUDENT="${STUDENT:-YourName}"          # <-- set: export STUDENT="Your Name"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
KEY_NAME="ewb-lab"
KEY_FILE="$HOME/.ssh/ewb-lab.pem"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/state.env"
EVIDENCE="$DIR/evidence"
mkdir -p "$EVIDENCE"
touch "$STATE"

# shellcheck disable=SC1090
source "$STATE"

save() { # save KEY VALUE  -> persists resource IDs between scripts
  sed -i "/^$1=/d" "$STATE"; echo "$1=$2" >> "$STATE"; export "$1=$2"
}

tags() { # tags <resource-type> <Name>
  echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT}]"
}

need() { for v in "$@"; do [[ -n "${!v:-}" ]] || { echo "Missing $v - run earlier scripts first." >&2; exit 1; }; done; }

log() { echo -e "\n== $* =="; }
