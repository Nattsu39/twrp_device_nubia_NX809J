#!/bin/bash
# ============================================================================
# 解析已拉取的 HAL 服务的动态库依赖闭包, 并从真机补齐
# 用法: bash resolve_libs.sh [设备树路径]
# 原理: 对每个 .so/bin 用 readelf -d 取 NEEDED, 在设备的搜索路径里找, 递归拉取
# ============================================================================
set -u
DT="${1:-device/nubia/NX809J}"
ROOT="$DT/recovery/root"
OUT="$ROOT/vendor/lib64"          # recovery 里统一放 vendor/lib64
mkdir -p "$OUT"

# 设备上的库搜索路径 (按 Android 默认优先级)
SEARCH="/vendor/lib64/hw /vendor/lib64 /odm/lib64 /system_ext/lib64 /system/lib64 \
        /vendor/lib /odm/lib /system_ext/lib /system/lib"

declare -A DONE
PULLED=0; NOTFOUND=0; MISSING_LIST=""

dev_size() { adb shell "su -c 'stat -c %s \"$1\" 2>/dev/null'" 2>/dev/null | tr -d '\r\n'; }

fetch() {  # fetch <库名>  -> 返回设备绝对路径(成功) / 空(失败)
  local name="$1" p
  for d in $SEARCH; do
    p="$d/$name"
    if [ -n "$(adb shell "su -c 'test -f \"$p\" && echo y'" 2>/dev/null | tr -d '\r')" ]; then
      echo "$p"; return 0
    fi
  done
  return 1
}

pull_to() {  # pull_to <设备绝对路径> <本地绝对路径>
  local src="$1" dst="$2" dsz lsz
  dsz=$(dev_size "$src")
  mkdir -p "$(dirname "$dst")"
  adb shell "su -c 'base64 \"$src\"'" 2>/dev/null | tr -d '\r\n' | base64 -d > "$dst" 2>/dev/null
  lsz=$(stat -c %s "$dst" 2>/dev/null || echo 0)
  if [ -n "$dsz" ] && [ "$dsz" = "$lsz" ] && [ "$lsz" != "0" ]; then
    return 0
  else
    rm -f "$dst"; return 1
  fi
}

deps_of() {  # 输出一个 ELF 的 NEEDED 列表
  readelf -d "$1" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'
}

queue=()
# 种子: 所有已拉取的 HAL 服务 / 可执行
while IFS= read -r f; do queue+=("$f"); done < <(find "$ROOT/vendor/bin" -type f 2>/dev/null)

echo "种子文件: ${#queue[@]} 个"
echo "开始解析依赖闭包..."
i=0
while [ $i -lt ${#queue[@]} ]; do
  cur="${queue[$i]}"; i=$((i+1))
  [ -f "$cur" ] || continue
  for need in $(deps_of "$cur"); do
    [ -n "${DONE[$need]:-}" ] && continue
    DONE[$need]=1
    # 本地已有就不用拉
    if [ -f "$OUT/$need" ]; then
      queue+=("$OUT/$need"); continue
    fi
    src=$(fetch "$need") || {
      # 系统库(libc/libm/libdl 等)不需要进 recovery
      case "$need" in
        libc.so|libm.so|libdl.so|libstdc++.so|liblog.so|libbase.so|libutils.so|libcutils.so|libbinder*.so) 
            echo "  ~ $need (系统库, 跳过)"; continue ;;
      esac
      echo "  ❌ 找不到: $need"; NOTFOUND=$((NOTFOUND+1)); MISSING_LIST="$MISSING_LIST $need"; continue
    }
    if pull_to "$src" "$OUT/$need"; then
      echo "  ✅ $need  <- $src"
      PULLED=$((PULLED+1)); queue+=("$OUT/$need")
    else
      echo "  ❌ 拉取失败: $need ($src)"; NOTFOUND=$((NOTFOUND+1)); MISSING_LIST="$MISSING_LIST $need"
    fi
  done
done

echo
echo "=============================================="
printf " 共拉取 %d 个依赖库, 未找到 %d 个\n" "$PULLED" "$NOTFOUND"
[ -n "$MISSING_LIST" ] && echo " 未找到:$MISSING_LIST" | tr ' ' '\n' | head -40
echo "=============================================="
