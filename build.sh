#!/usr/bin/env bash
# 构建：编译 dylib -> 注入 IPA -> ldid 重签 -> 重新打包
#
# 用法: ./build.sh <原始解密版.ipa> [输出.ipa]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <original.ipa> [output.ipa]"
  exit 1
fi

SRC_IPA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUT_IPA="${2:-QiShuiMusic_NoForceUpdate.ipa}"

# 交叉编译环境（按需覆盖）
TOOLCHAIN="${TOOLCHAIN:-/workspace/ios-toolchain/ios-arm64e-clang-toolchain/bin}"
SDK="${SDK:-/workspace/ios-sdks/iPhoneOS15.6.sdk}"
LDID="${LDID:-/workspace/rea-work/ldid/ldid}"
LDID_LIB="${LDID_LIB:-/workspace/rea-work/lib}"
TINFO_LIB="${TINFO_LIB:-/workspace/ios-toolchain/libtinfo5/lib/x86_64-linux-gnu:/workspace/ios-toolchain/libtinfo5/usr/lib/x86_64-linux-gnu}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/build"
DYLIB_NAME="SodaUpdateFix.dylib"

rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

echo "[1/5] 编译 dylib"
LD_LIBRARY_PATH="$TINFO_LIB" "$TOOLCHAIN/clang" \
  -target arm64-apple-ios15.0 -isysroot "$SDK" \
  -dynamiclib -O2 -fno-objc-arc -lobjc \
  -o "$DYLIB_NAME" "$ROOT/SodaUpdateFix.m"

echo "[2/5] 解包 IPA"
unzip -q "$SRC_IPA" -d unwrap
APP="$(find unwrap/Payload -maxdepth 1 -name '*.app' | head -1)"
BIN_NAME="$(python3 -c "import plistlib;print(plistlib.load(open('$APP/Info.plist','rb'))['CFBundleExecutable'])")"

echo "[3/5] 注入 dylib: $BIN_NAME"
cp "$DYLIB_NAME" "$APP/Frameworks/"
python3 "$ROOT/patch_load_command.py" "$APP/$BIN_NAME" \
  "@executable_path/Frameworks/$DYLIB_NAME"

echo "[4/5] 签名"
LD_LIBRARY_PATH="$LDID_LIB" "$LDID" -e "$APP/$BIN_NAME" > ent.plist
rm -rf "$APP/_CodeSignature"
LD_LIBRARY_PATH="$LDID_LIB" "$LDID" -S"$WORK/ent.plist" "$APP/Frameworks/$DYLIB_NAME"
LD_LIBRARY_PATH="$LDID_LIB" "$LDID" -S"$WORK/ent.plist" "$APP/$BIN_NAME"

echo "[5/5] 打包"
rm -f "$ROOT/$OUT_IPA"
(cd unwrap && zip -qry -1 "$ROOT/$OUT_IPA" Payload)

echo "done: $ROOT/$OUT_IPA"
