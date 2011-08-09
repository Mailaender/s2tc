#!/bin/sh

set -e

exec 4>&1
exec 1>&2

cd ..
make clean || true
sh autogen.sh
./configure --prefix="`pwd`/tests" --enable-shared --disable-static "$@"
make
make install
cd tests

rm -rf html
rm -f *.dds
mkdir html
exec 3>html/index.html

html_start()
{
	echo >&3 "<html><title>S2TC</title>"
	cat <<'EOF' >&3
<script type="text/javascript" src="http://code.jquery.com/jquery-1.6.2.min.js"></script>
<script type="text/javascript">
var refsrc = "";
function clickfunc()
{
	var me = $(this);
	if(!me.data("src"))
		me.data("src", me.attr("src"));
	me.attr("src", me.data("src"));
	if(refsrc == me.data("src"))
		refsrc = "";
	else
		refsrc = me.data("src");
}
function enterfunc()
{
	var me = $(this);
	if(!me.data("src"))
		me.data("src", me.attr("src"));
	if(refsrc != "")
		me.attr("src", refsrc);
}
function leavefunc()
{
	var me = $(this);
	if(me.data("src"))
		me.attr("src", me.data("src"));
}
function run()
{
	$('img').click(clickfunc);
	$('img').mouseenter(enterfunc);
	$('img').mouseleave(leavefunc);
}
</script>
EOF
	echo >&3 "<body onLoad=\"run()\"><h1>S2TC</h1>"
	echo >&3 "<table>"
	echo >&3 "<tr><th>Picture</th>"
	echo >&3 "<th>Original</th>"

	col=1

	coltitle "sixteen"
	if $use_compressonator; then
		coltitle "compressonator"
		coltitle "compressonator->S2TC"
	fi
	if $use_nvcompress; then
		coltitle "nvcompress"
		coltitle "nvcompress->S2TC"
	fi
	coltitle "rand32_sRGB_mixed_l"

	if $use_libtxc_dxtn; then
		coltitle "libtxc_dxtn"
		coltitle "libtxc_dxtn-S2TC"
	fi
	coltitle "faster_wavg_a"
	coltitle "faster_wavg_l"

	echo >&3 "</tr>"
}
html_rowstart()
{
	echo >&3 "<tr><th>$1</th>"
	deltatime=
	deltatime_raw=0
	col=0
}

decompress()
{
	case "$1" in
		*.dds)
			convert "$1" TGA:-
			;;
		*)
			cat "$1"
			;;
	esac
}

coltitle()
{
	echo >&3 "<th>$1</th>"
	eval "title_$col=\$1"
	col=$(($col+1))
}
html()
{
	decompress "$1" | convert TGA:- -crop 256x256+192+128 "html/$1.png"
	echo >&3 "<td><img src=\"$1.png\" alt=\"$1\" title=\"$1$deltatime\"></td>"
	eval "prevdeltatime=\$deltatime_$col"
	prevdeltatime=`echo "($prevdeltatime-0)+$deltatime_raw" | bc`
	eval "deltatime_$col=\$prevdeltatime"
	col=$(($col+1))
}
html_rowend()
{
	echo >&3 "</tr>"
}
html_end()
{
	echo >&3 "<tr><th>Total runtime</th><td>(original)</td>"
	col=1
	echo >&4 "good=true"
	while :; do
		eval "prevdeltatime=\$deltatime_$col"
		[ -n "$prevdeltatime" ] || break
		eval "title=\$title_$col"
		deltatime=`echo "scale=3; $prevdeltatime / 1000000000" | bc -l`
		echo >&4 "$title=$deltatime"
		echo >&3 "<td>$deltatime seconds</td>"
		col=$(($col+1))
	done
	echo >&3 "</table></body></html>"
}

timing()
{
	t0=`date +%s%N`
	"$@"
	t1=`date +%s%N`
	deltatime_raw=`echo "$t1 - $t0" | bc`
	deltatime=`echo "scale=3; $deltatime_raw / 1000000000" | bc -l`
	deltatime=" ($deltatime seconds)"
}

t()
{
	in=$1; shift
	out=$1; shift
	timing "$@" < "$in" > "$out"
	html "$out"
}

: ${use_external:=true}
if $use_external && which nvcompress >/dev/null 2>&1; then
	: ${use_nvcompress:=true}
else
	: ${use_nvcompress:=false}
fi
if $use_external && which wine >/dev/null 2>&1 && [ -f "$HOME/.wine/drive_c/Program Files (x86)/AMD/The Compressonator 1.50/TheCompressonator.exe" ]; then
	: ${use_compressonator:=true}
else
	: ${use_compressonator:=false}
fi
if $use_external && [ -f /usr/lib/libtxc_dxtn.so ]; then
	: ${use_libtxc_dxtn:=true}
else
	: ${use_libtxc_dxtn:=false}
fi

html_start

# TODO download test pictures that are not under the same license as this package
xon()
{
	# downloads a texture from Xonotic
	if ! [ -f "$2" ]; then
		wget -O- "http://git.xonotic.org/?p=xonotic/xonotic-maps.pk3dir.git;a=blob_plain;f=$1" | convert "${1##*.}":- -geometry 512x512 "$2"
	fi
}
# floor_tread01_norm: GPLv2+
xon textures/exx/floor/floor_tread01_norm.tga floor_tread01_norm.tga
# base_concrete1a: GPLv2+
xon textures/trak4x/base/base_concrete1a.tga base_concrete1a.tga
# disabled: GPLv2+
xon textures/screens/screen_toggle0.tga disabled.tga
# lift02: GPLv2+
xon textures/facility114x/misc/lift02.tga lift02.tga
# sunset: GPLv2+
xon env/distant_sunset/distant_sunset_rt.jpg sunset.tga
# amelia: no license
if ! [ -f "amelia.tga" ]; then
	wget -O- "http://www.godoon.com/gallery/media/slayers/amelia-wil-tesla-saillune/49212997-d81e-11df-8228-a8bfc396a36f.jpg" | convert JPG:- amelia.tga
fi
# grass: no license
if ! [ -f "ba_grass_cc.tga" ]; then
	wget -O- http://sauerbraten.svn.sourceforge.net/viewvc/sauerbraten/packages/blindabuser/ba_grass_cc.jpg | convert JPG:- ba_grass_cc.tga
fi

export LD_LIBRARY_PATH="$PWD/lib"
for i in ba_grass_cc dxtfail floor_tread01_norm fract001 base_concrete1a disabled lift02 sunset amelia noise noise_solid supernova; do
	html_rowstart "$i"

	html "$i".tga

	case "$i" in
		*_norm*)
			goodmetric=NORMALMAP
			fourcc=DXT5
			nvopts="-bc3 -alpha"
			;;
		*)
			goodmetric=SRGB_MIXED
			fourcc=DXT1
			nvopts="-bc1"
			;;
	esac

	t "$i".tga "$i"-16colors.tga convert TGA:- -colors 16 TGA:-

	if $use_compressonator; then
		timing wine "c:/Program Files (x86)/AMD/The Compressonator 1.50/TheCompressonator.exe" -convert -overwrite -mipmaps "$i".tga "$i"-amdcompress.dds -codec DXTC.dll +fourCC $fourcc -mipper BoxFilter.dll
		html "$i"-amdcompress.dds
		timing bin/s2tc_from_s3tc -i "$i"-amdcompress.dds -o "$i"-amdcompress-s2tc.dds
		html "$i"-amdcompress-s2tc.dds
	fi

	if $use_nvcompress; then
		timing nvcompress $nvopts "$i".tga "$i"-nvcompress.dds
		html "$i"-nvcompress.dds
		timing bin/s2tc_from_s3tc -i "$i"-nvcompress.dds -o "$i"-nvcompress-s2tc.dds
		html "$i"-nvcompress-s2tc.dds
	fi

	S2TC_DITHER_MODE=FLOYDSTEINBERG S2TC_COLORDIST_MODE=$goodmetric S2TC_RANDOM_COLORS=32 S2TC_REFINE_COLORS=LOOP \
	t "$i".tga "$i"-rand32-mrgb-l.dds bin/s2tc_compress -t $fourcc
	if $use_libtxc_dxtn; then
		t "$i".tga "$i"-libtxc_dxtn.dds   bin/s2tc_compress -t $fourcc -l /usr/lib/libtxc_dxtn.so
		timing bin/s2tc_from_s3tc -i "$i"-libtxc_dxtn.dds -o "$i"-libtxc_dxtn-s2tc.dds
		html "$i"-libtxc_dxtn-s2tc.dds
	fi
	S2TC_DITHER_MODE=SIMPLE         S2TC_COLORDIST_MODE=WAVG        S2TC_RANDOM_COLORS=-1 S2TC_REFINE_COLORS=ALWAYS \
	t "$i".tga "$i"-faster-wavg-r.dds bin/s2tc_compress -t $fourcc
	S2TC_DITHER_MODE=SIMPLE         S2TC_COLORDIST_MODE=WAVG        S2TC_RANDOM_COLORS=-1 S2TC_REFINE_COLORS=LOOP \
	t "$i".tga "$i"-faster-wavg-l.dds bin/s2tc_compress -t $fourcc

	html_rowend
done
html_end
