#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
raw_dir="$repo_dir/docs/app-store/screenshots/raw"
final_dir="$repo_dir/docs/app-store/screenshots/final"
font="/System/Library/Fonts/STHeiti Medium.ttc"

mkdir -p "$final_dir"

render() {
  local input=$1
  local output=$2
  local title=$3
  local subtitle=$4
  local accent=$5
  local staged
  staged=$(mktemp /tmp/shouxia-shot.XXXXXX.png)

  magick "$input" \
    -resize "1040x2260^" \
    -gravity north \
    -crop "1040x2260+0+0" \
    +repage \
    \( +clone -alpha extract -draw "fill black polygon 0,0 0,42 42,0 fill white roundrectangle 0,0 1039,2259 42,42" \) \
    -alpha off -compose CopyOpacity -composite \
    "$staged"

  magick -size 1320x2868 "gradient:#F7FBFA-#DCEFEA" \
    -fill "$accent" -draw "roundrectangle 92,116 248,128 6,6" \
    -font "$font" -fill "#233A35" -pointsize 78 -gravity north \
    -annotate "+0+168" "$title" \
    -fill "#60756F" -pointsize 36 \
    -annotate "+0+282" "$subtitle" \
    \( "$staged" -background "#19363033" -shadow "42x24+0+22" \) \
    -gravity north -geometry "+0+454" -compose over -composite \
    "$staged" \
    -gravity north -geometry "+0+432" -compose over -composite \
    -alpha off -colorspace sRGB -strip \
    "$output"

  rm -f "$staged"
}

render "$raw_dir/01-home.png" \
  "$final_dir/01-pickup-codes.png" \
  "取件码，都在这里" \
  "不用翻短信，打开就能找到" \
  "#79B8A6"

render "$raw_dir/02-local-privacy.png" \
  "$final_dir/02-on-device.png" \
  "图片只在本机识别" \
  "不上传原图，不保留无关文字" \
  "#F3A37F"

render "$raw_dir/03-automation.png" \
  "$final_dir/03-message-automation.png" \
  "短信也可以自动进来" \
  "一次设置，之后不用复制" \
  "#79B8A6"

render "$raw_dir/04-large-code.png" \
  "$final_dir/04-large-code.png" \
  "三秒找到取件码" \
  "同一地点多件，左右切换" \
  "#F3A37F"

render "$raw_dir/05-completed.png" \
  "$final_dir/05-swipe-complete.png" \
  "取完向右一滑" \
  "轻轻完成，五秒内可撤销" \
  "#79B8A6"
