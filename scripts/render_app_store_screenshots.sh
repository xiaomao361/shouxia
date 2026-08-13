#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
raw_dir="$repo_dir/docs/app-store/screenshots/raw"
master_dir="$repo_dir/docs/app-store/screenshots/final-7"
final_dir="$repo_dir/docs/app-store/screenshots/final-7-6.5"
font="/System/Library/Fonts/STHeiti Medium.ttc"

mkdir -p "$master_dir" "$final_dir"

temp_dir=$(mktemp -d /tmp/shouxia-seven-shots.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT

make_phone() {
  local input=$1
  local output=$2
  local width=$3
  local radius=${4:-54}
  local resized="$temp_dir/resized-${output:t}"
  local mask="$temp_dir/mask-${output:t}"
  local dimensions
  local height

  magick "$input" -resize "${width}x" -alpha off -colorspace sRGB "$resized"
  dimensions=$(identify -format "%wx%h" "$resized")
  height=${dimensions#*x}

  magick -size "$dimensions" xc:none \
    -fill white \
    -draw "roundrectangle 0,0,$((width - 1)),$((height - 1)),$radius,$radius" \
    "$mask"

  magick "$resized" "$mask" \
    -alpha off -compose CopyOpacity -composite \
    "$output"
}

make_crop() {
  local input=$1
  local output=$2
  local geometry=$3
  local width=$4
  local radius=${5:-48}
  local cropped="$temp_dir/cropped-${output:t}"

  magick "$input" -crop "$geometry" +repage "$cropped"
  make_phone "$cropped" "$output" "$width" "$radius"
}

make_base() {
  local output=$1
  local top=$2
  local bottom=$3

  magick -size 1320x2868 "gradient:${top}-${bottom}" \
    -alpha off -colorspace sRGB "$output"
}

add_header() {
  local input=$1
  local output=$2
  local eyebrow=$3
  local title=$4
  local subtitle=$5
  local accent=$6
  local title_size=${7:-76}

  magick "$input" \
    -font "$font" \
    -fill "$accent" -pointsize 28 -gravity northwest \
    -annotate "+96+118" "$eyebrow" \
    -fill "#203A35" -pointsize "$title_size" \
    -annotate "+96+180" "$title" \
    -fill "#60756F" -pointsize 34 \
    -annotate "+98+380" "$subtitle" \
    "$output"
}

place_phone() {
  local input=$1
  local phone=$2
  local output=$3
  local x=$4
  local y=$5
  local shadow_opacity=${6:-28}

  magick "$input" \
    \( "$phone" -background "#173A34${shadow_opacity}" -shadow "46x26+0+28" \) \
    -geometry "+${x}+$((y + 18))" -compose over -composite \
    "$phone" -geometry "+${x}+${y}" -compose over -composite \
    "$output"
}

draw_pill() {
  local input=$1
  local output=$2
  local x1=$3
  local y1=$4
  local x2=$5
  local y2=$6
  local fill=$7
  local text=$8
  local text_fill=${9:-"#203A35"}
  local point_size=${10:-28}

  magick "$input" \
    -fill "$fill" -stroke "#FFFFFFAA" -strokewidth 2 \
    -draw "roundrectangle $x1,$y1 $x2,$y2 34,34" \
    -font "$font" -fill "$text_fill" -stroke none -pointsize "$point_size" \
    -gravity northwest -annotate "+$((x1 + 28))+$((y1 + 22))" "$text" \
    "$output"
}

render_hero() {
  local base="$temp_dir/hero-base.png"
  local headed="$temp_dir/hero-headed.png"
  local staged="$temp_dir/hero-staged.png"
  local phone="$temp_dir/hero-phone.png"
  local pills="$temp_dir/hero-pills.png"

  make_base "$base" "#F3FBF9" "#F9E6D8"
  add_header \
    "$base" "$headed" \
    "取件码收件箱" \
    $'自己的自动收，\n别人托的也收下' \
    "到驿站时，不用再翻短信和聊天记录" \
    "#4C9C88" 78

  draw_pill "$headed" "$pills" \
    96 504 585 584 "#D8F0E8" "自己的短信  ·  自动收"
  draw_pill "$pills" "$staged" \
    635 504 1224 584 "#FFE3D1" "家人朋友  ·  粘贴 / 识图"

  magick "$staged" \
    -stroke "#79B8A6" -strokewidth 5 -fill none \
    -draw "path 'M 340 590 C 420 640, 520 655, 620 692'" \
    -stroke "#E99A78" \
    -draw "path 'M 930 590 C 850 640, 760 655, 690 692'" \
    "$staged"

  make_phone "$raw_dir/01-home-dual.png" "$phone" 1000 62
  place_phone "$staged" "$phone" "$master_dir/01-dual-intake.png" 160 674 30
}

render_friend_input() {
  local base="$temp_dir/input-base.png"
  local headed="$temp_dir/input-headed.png"
  local crop="$temp_dir/input-crop.png"
  local staged="$temp_dir/input-staged.png"
  local cards="$temp_dir/input-cards.png"
  local fixture="$temp_dir/input-fixture.png"

  make_base "$base" "#FFF8F1" "#E7F4F0"
  add_header \
    "$base" "$headed" \
    "家人朋友托你取的" \
    "粘贴文字，或者识别截图" \
    "两种入口都在首页，不需要转发给另一个账号" \
    "#E8916F" 70

  make_crop "$raw_dir/01-home-dual.png" "$crop" "1206x1440+0+0" 1080 58
  place_phone "$headed" "$crop" "$staged" 120 600 24

  magick "$staged" \
    -fill "#FFFFFFD8" -stroke "#FFFFFF" -strokewidth 2 \
    -draw "roundrectangle 96,2020 632,2620 42,42" \
    -draw "roundrectangle 688,2020 1224,2620 42,42" \
    -font "$font" -stroke none \
    -fill "#4C9C88" -pointsize 26 -gravity northwest \
    -annotate "+132+2062" "文字" \
    -fill "#203A35" -pointsize 34 \
    -annotate "+132+2132" $'家人托取\n云朵花园丰巢柜' \
    -fill "#60756F" -pointsize 28 \
    -annotate "+132+2325" "取件码  3-7-2608" \
    -fill "#E8916F" -pointsize 26 \
    -annotate "+724+2062" "截图" \
    "$cards"

  magick "$repo_dir/docs/app-store/screenshots/fixtures/demo-logistics-card.png" \
    -resize "452x452^" -gravity center -crop "452x452+0+0" +repage \
    "$fixture"

  magick "$cards" \
    \( "$fixture" -background "#173A3420" -shadow "24x12+0+12" \) \
    -geometry "+730+2130" -compose over -composite \
    "$fixture" -geometry "+730+2118" -compose over -composite \
    "$master_dir/02-friends-paste-or-photo.png"
}

render_system_step() {
  local input=$1
  local output=$2
  local step=$3
  local title=$4
  local subtitle=$5
  local top=$6
  local bottom=$7
  local accent=$8
  local phone="$temp_dir/system-${step}-phone.png"
  local base="$temp_dir/system-${step}-base.png"
  local headed="$temp_dir/system-${step}-headed.png"
  local staged="$temp_dir/system-${step}-staged.png"

  make_base "$base" "$top" "$bottom"
  add_header "$base" "$headed" "短信自动收码 · 第 ${step} 步" "$title" "$subtitle" "$accent" 72

  magick "$headed" \
    -fill "#FFFFFFB8" -stroke "#FFFFFF" -strokewidth 2 \
    -draw "roundrectangle 96,486 1224,572 40,40" \
    -font "$font" -pointsize 28 -stroke none \
    -fill "$([ "$step" = "1" ] && echo "#203A35" || echo "#8BA09A")" \
    -gravity northwest -annotate "+132+512" "1  添加快捷指令" \
    -fill "#9CB1AB" -annotate "+568+512" "→" \
    -fill "$([ "$step" = "2" ] && echo "#203A35" || echo "#8BA09A")" \
    -annotate "+650+512" "2  创建个人自动化" \
    "$staged"

  make_phone "$input" "$phone" 980 62
  place_phone "$staged" "$phone" "$output" 170 624 25
}

render_privacy() {
  local base="$temp_dir/privacy-base.png"
  local headed="$temp_dir/privacy-headed.png"
  local phone="$temp_dir/privacy-phone.png"
  local staged="$temp_dir/privacy-staged.png"
  local pills="$temp_dir/privacy-pills.png"

  make_base "$base" "#FFF3EA" "#E4F3EF"
  add_header \
    "$base" "$headed" \
    "本地优先" \
    "图片只在本机识别" \
    "不上传原图，也不保留手机号、运单号等无关文字" \
    "#E8916F" 76

  make_phone "$raw_dir/05-on-device-new.png" "$phone" 930 58
  place_phone "$headed" "$phone" "$staged" 195 580 25

  draw_pill "$staged" "$pills" \
    120 2618 460 2702 "#FFFFFFC8" "不建账号" "#4E6962" 26
  draw_pill "$pills" "$staged" \
    490 2618 830 2702 "#FFFFFFC8" "不做跟踪" "#4E6962" 26
  draw_pill "$staged" "$master_dir/05-on-device.png" \
    860 2618 1200 2702 "#FFFFFFC8" "不上传图片" "#4E6962" 26
}

render_large_code() {
  local base="$temp_dir/large-base.png"
  local headed="$temp_dir/large-headed.png"
  local phone="$temp_dir/large-phone.png"
  local staged="$temp_dir/large-staged.png"

  make_base "$base" "#E8F7F3" "#FAEEE5"
  add_header \
    "$base" "$headed" \
    "到了驿站" \
    "一眼找到取件码" \
    "同一地点多件，左右切换" \
    "#4C9C88" 80

  magick "$headed" \
    -fill "#79B8A61C" -stroke "#79B8A633" -strokewidth 4 \
    -draw "circle 1140,430 1280,430" \
    -draw "circle 1140,430 1220,430" \
    "$staged"

  make_phone "$raw_dir/06-large-code-new.png" "$phone" 1060 62
  place_phone "$staged" "$phone" "$master_dir/06-large-code.png" 130 570 28
}

render_completion() {
  local base="$temp_dir/done-base.png"
  local headed="$temp_dir/done-headed.png"
  local phone="$temp_dir/done-phone.png"
  local staged="$temp_dir/done-staged.png"

  make_base "$base" "#EEF8F5" "#F9E7D9"
  add_header \
    "$base" "$headed" \
    "取完了" \
    "向右一滑，轻轻收下" \
    "完成后五秒内，还可以撤销" \
    "#4C9C88" 74

  magick "$headed" \
    -fill "#F3A37F22" -stroke "#F3A37F44" -strokewidth 5 \
    -draw "roundrectangle 920,164 1220,450 70,70" \
    -draw "path 'M 985 300 L 1060 370 L 1170 235'" \
    "$staged"

  make_phone "$raw_dir/07-completed-new.png" "$phone" 1000 62
  place_phone "$staged" "$phone" "$master_dir/07-swipe-complete.png" 160 584 28
}

render_hero
render_friend_input

render_system_step \
  "$raw_dir/03-add-shortcut.png" \
  "$master_dir/03-add-shortcut.png" \
  "1" \
  "一步添加“收下自动收码”" \
  "确认名称后，点“添加快捷指令”" \
  "#F5F8FA" "#E3F0EC" "#4C9C88"

render_system_step \
  "$raw_dir/04-personal-automation.png" \
  "$master_dir/04-message-automation.png" \
  "2" \
  "设置一次，以后自动进来" \
  "信息包含“取件”时，立即运行收下自动收码" \
  "#F6F4FA" "#E8F2EF" "#4C9C88"

render_privacy
render_large_code
render_completion

for screenshot in "$master_dir"/*.png; do
  magick "$screenshot" \
    -resize "1242x2688!" \
    -alpha off -colorspace sRGB -strip -depth 8 \
    "$final_dir/${screenshot:t}"
done

echo "Rendered 7 App Store screenshots:"
identify "$final_dir"/*.png
