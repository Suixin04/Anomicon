#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# != 2 ]]; then
  printf '用法: %s <app-release.aab> <上传证书 SHA-256>\n' "$0" >&2
  exit 2
fi

bundle=$1
normalize_fingerprint() {
  tr -d ':' | tr '[:lower:]' '[:upper:]'
}
expected=$(printf '%s' "$2" | normalize_fingerprint)
if [[ ! "$expected" =~ ^[0-9A-F]{64}$ ]]; then
  printf '%s\n' '上传证书 SHA-256 格式无效。' >&2
  exit 2
fi

verification=$(jarsigner -J-Duser.language=en -J-Duser.country=US -verify "$bundle")
if ! printf '%s\n' "$verification" | grep -Fxq 'jar verified.' ||
   [[ "$verification" == *'contains unsigned entries'* ]]; then
  printf '%s\n' 'AAB 签名完整性验证失败。' >&2
  exit 1
fi

certificate_info=$(keytool -J-Duser.language=en -J-Duser.country=US -printcert -jarfile "$bundle")
actual=$(printf '%s\n' "$certificate_info" | awk '
  /^Signer #[0-9]+:/ { signers++; leaf = 1 }
  $1 == "SHA256:" && leaf { fingerprint = $2; leaf = 0 }
  END { if (signers == 1) print fingerprint }
' | normalize_fingerprint)
if [[ "$actual" != "$expected" ]]; then
  printf '%s\n' 'AAB 须由唯一一张与预期指纹匹配的上传证书签名。' >&2
  exit 1
fi
printf '%s\n' 'AAB 签名完整性和上传证书指纹均已验证。'
