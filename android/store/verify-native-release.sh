#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

project=$(cd "${1:?传入原生 Gradle 项目路径}" && pwd)
expected=$(printf '%s' "${2:?传入上传证书 SHA-256}" | tr -d ':' | tr '[:lower:]' '[:upper:]')
[[ "$expected" =~ ^[A-F0-9]{64}$ ]] || { echo '上传证书指纹格式无效' >&2; exit 2; }
: "${BUNDLETOOL_JAR:?设置 bundletool JAR 路径}"
: "${ANDROID_HOME:?设置 Android SDK 路径}"
: "${LLVM_READELF:?设置 NDK llvm-readelf 路径}"
: "${JAVA_HOME:?设置 JDK 17 路径}"
export PATH="$JAVA_HOME/bin:$PATH"
build_tools="$ANDROID_HOME/build-tools/35.0.0"

cd "$project"
if [[ $# -eq 3 ]]; then
  build_options=("-PversionCode=$3")
  ./gradlew --no-daemon :app:bundleRelease :app:assembleRelease "${build_options[@]}"
else
  ./gradlew --no-daemon :app:bundleRelease :app:assembleRelease
fi

bundle=app/build/outputs/bundle/release/app-release.aab
apk=app/build/outputs/apk/release/app-release.apk
verification=$(jarsigner -J-Duser.language=en -J-Duser.country=US -verify "$bundle")
printf '%s\n' "$verification" | grep -Fxq 'jar verified.'
[[ "$verification" != *'contains unsigned entries'* ]]
actual=$(keytool -J-Duser.language=en -J-Duser.country=US -printcert -jarfile "$bundle" | awk '
  /^Signer #[0-9]+:/ { count++; leaf = 1 }
  $1 == "SHA256:" && leaf { print $2; leaf = 0 }
  END { if (count != 1) exit 1 }
' | tr -d ':' | tr '[:lower:]' '[:upper:]')
[[ "$actual" == "$expected" ]] || { echo 'AAB 上传证书指纹不匹配' >&2; exit 1; }
actual=$("$build_tools/apksigner" verify --print-certs "$apk" | awk '/^Signer #[0-9]+ certificate SHA-256 digest:/ { print $NF }' | tr '[:lower:]' '[:upper:]')
[[ "$actual" == "$expected" ]] || { echo 'APK 签名证书指纹不匹配' >&2; exit 1; }
printf 'AAB、APK 上传证书 SHA-256 %s\n' "$expected"

java -jar "$BUNDLETOOL_JAR" validate --bundle="$bundle"
config=$(java -jar "$BUNDLETOOL_JAR" dump config --bundle="$bundle")
[[ "$config" == *PAGE_ALIGNMENT_16K* ]] || { echo 'AAB 缺少 PAGE_ALIGNMENT_16K' >&2; exit 1; }
manifest=$(java -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$bundle" --module=base)
apk_manifest=$("$build_tools/aapt2" dump badging "$apk")
"$build_tools/zipalign" -c -P 16 4 "$apk"

python3 - "$project" "$bundle" "$apk" "$manifest" "$apk_manifest" "${3-}" <<'PY'
import hashlib
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
from xml.etree import ElementTree
from zipfile import ZIP_STORED, ZipFile

project, bundle, apk, manifest, apk_manifest, requested_version = sys.argv[1:]
android = '{http://schemas.android.com/apk/res/android}'
root = ElementTree.fromstring(manifest)
package = root.get('package')
version_name = root.get(android + 'versionName')
version_code = root.get(android + 'versionCode')
sdk = root.find('uses-sdk')
min_sdk = sdk.get(android + 'minSdkVersion')
target_sdk = sdk.get(android + 'targetSdkVersion')
if (package != 'com.suixin.anomicon' or min_sdk != '26' or int(target_sdk) < 36
        or (requested_version and version_code != requested_version)):
    sys.exit(f'Unexpected AAB metadata: {package} {version_name} {version_code} {min_sdk} {target_sdk}')
expected_metadata = (f"name='{package}'", f"versionCode='{version_code}'", f"versionName='{version_name}'",
                     f"minSdkVersion:'{min_sdk}'", f"targetSdkVersion:'{target_sdk}'")
if not all(item in apk_manifest for item in expected_metadata):
    sys.exit('APK metadata differs from AAB metadata')
print(f'{package} {version_name} ({version_code}), API {min_sdk}–{target_sdk}')

asset_dir = Path(project) / 'feature/archive3d/src/main/assets/models'
models = {path.name: path.read_bytes() for path in asset_dir.glob('*.glb')}
required_models = {'scp-049.glb', 'scp-106.glb', 'scp-173.glb', 'scp-939.glb'}
if not required_models <= models.keys():
    sys.exit(f'Missing source models: {required_models - models.keys()}')
for name, payload in sorted(models.items()):
    if struct.unpack_from('<4sII', payload) != (b'glTF', 2, len(payload)):
        sys.exit(f'Invalid GLB header: {name}')

with tempfile.TemporaryDirectory() as scratch:
    elf = Path(scratch) / 'library.so'
    for archive_path, prefix in ((bundle, 'base/'), (apk, '')):
        with ZipFile(archive_path) as archive:
            asset_prefix = prefix + 'assets/models/'
            packaged = {info.filename.removeprefix(asset_prefix): info for info in archive.infolist()
                        if info.filename.startswith(asset_prefix) and info.filename.endswith('.glb')}
            if packaged.keys() != models.keys():
                sys.exit(f'{archive_path}: packaged model set does not match source')
            for name, model in models.items():
                if archive.read(packaged[name]) != model:
                    sys.exit(f'{archive_path}: model differs from source: {name}')
                if not prefix and packaged[name].compress_type != ZIP_STORED:
                    sys.exit(f'{archive_path}: model must be available uncompressed: {name}')
            elf_counts = {}
            for entry in archive.namelist():
                match = re.fullmatch(prefix + r'lib/([^/]+)/[^/]+\.so', entry)
                if match is None:
                    continue
                abi, = match.groups()
                elf.write_bytes(archive.read(entry))
                headers = subprocess.check_output([os.environ['LLVM_READELF'], '-lW', str(elf)], text=True)
                sizes = [int(line.split()[-1], 0) for line in headers.splitlines()
                         if line.strip().startswith('LOAD ')]
                if not sizes or min(sizes) < 16384:
                    sys.exit(f'{archive_path}: PT_LOAD must be 16 KiB aligned: {entry} {sizes}')
                elf_counts[abi] = elf_counts.get(abi, 0) + 1
            if not {'arm64-v8a', 'x86_64'} <= elf_counts.keys():
                sys.exit(f'{archive_path}: missing expected 64-bit native ABIs')
            print(f'{archive_path}: models {", ".join(sorted(models))}, ELF counts {elf_counts}')
        with open(archive_path, 'rb') as artifact:
            digest = hashlib.sha256()
            for chunk in iter(lambda: artifact.read(1024 * 1024), b''):
                digest.update(chunk)
        print(f'SHA-256 {digest.hexdigest()}  {archive_path}')
PY
