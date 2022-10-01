#!/usr/bin/perl
use Getopt::Long;
use 5.010; # use feature 'say'
use strict;
use warnings;

# https://stackoverflow.com/questions/26625876/how-to-get-image-whole-pixels-rgb-color-with-imagemagick
# https://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# https://stackoverflow.com/questions/15682537/ansi-color-specific-rgb-sequence-bash
# This guy made something similar: https://dom111.github.io/image-to-ansi/ but his colors are weird
#
# To create a palette:
#  ./printcolors.sh  |awk '{print $2}' |while read x;do echo "xc:'$x' \\";done >generate_RGB256palette.sh
#  Line 1: convert xc:'#000000' \
#  Line last: +append palette.gif
#  Then:  convert image.png +dither -remap palette.gif result.png

my ($WIDTH, $Hcompress, $RGB256, $xtra, $verbose, $inputfile,$outputfile, $zlib) = (32,0,0,'',0);
Getopt::Long::Configure ("bundling");
GetOptions (
	"w|WIDTH=s" => \$WIDTH,
	"r|RGB256+" => \$RGB256,
	"i|inputfile=s" => \$inputfile,
	"o|outputfile=s" => \$outputfile,
	"c|COMPRESS" => \$Hcompress,
	"z|zlib" => \$zlib,
	"v|verbose+" => \$verbose,
	"x|xtra=s" => \$xtra,
) or die usage();

die usage() unless defined $inputfile;

say "DEBUG: ($inputfile =($WIDTH;r:$RGB256;c:$Hcompress;z=$zlib)> $outputfile)" if $verbose;

my $UPPER="▀"; # https://www.fileformat.info/info/unicode/char/2580/index.htm
my $LOWER="▄"; # https://www.fileformat.info/info/unicode/char/2584/index.htm

my ($mX,$mY); # max width/height
my (%D,%T); # hash/dict T contains the color number and D ansicode.

# Pipe an imagemagick command into a filehandle. Reads lines like: 31,31,srgb(184,165,153)
my $cmd = "convert $inputfile $xtra -resize $WIDTH "
	.($RGB256>1?"-depth 8 ":"")
	."sparse-color: | tr ' ' '\\n'|"; 
say $cmd if $verbose>1;
open(FIN,$cmd) or die $!;

if($outputfile){
	open(FOUT,'>',$outputfile) or die $!;
}

# Read file and fill hash pixel data
while(defined($_=<FIN>)){
	my ($x,$y,$srgb,$r,$g,$b) = split /[(),]/,$_;
	if($RGB256){
		$D{$x}{$y}= $y%2? fg256($r,$g,$b) : bg256($r,$g,$b);
		$T{$x}{$y}= rgbToAnsi256($r,$g,$b);
	}else{
		$D{$x}{$y}= $y%2? fg($r,$g,$b) : bg($r,$g,$b);
		$T{$x}{$y}="$r,$g,$b";
	}
	$mX=$x;$mY=$y; 
}

# Print Halfblocks ($LOWER) and grab 2 pixel rows to use as foreground and background color.
for(my $y=0+0*8;$y<$mY-0*7;$y+=2){
	print FOUT 'echo -e "' if($outputfile); 
	my $s;
	for(my $x=0+0*2;$x<$mX-0*10;++$x){
		if($Hcompress && $x>0){
			my $upisdown     =       $T{$x}{$y}   eq $T{$x}{$y+1};
			my $wasupdown    = $x>0? $T{$x-1}{$y} eq $T{$x-1}{$y+1} :0; 
			my $sameprevup   = $x>0? $T{$x}{$y}   eq $T{$x-1}{$y} :0;
			my $sameprevdown = $x>0? $T{$x}{$y+1} eq $T{$x-1}{$y+1} :0;
			my $settopcolor = !$sameprevup ? 'T' : 't';
			my $setbottomcolor=!$sameprevdown? 'B':'b';
			my $setspace = $upisdown&&$wasupdown ? 'S':'s';
			#say restore()."#($x,$y){$upisdown,$wasupdown,$sameprevup,$sameprevdown}($T{$x}{$y}|$T{$x}{$y+1})$settopcolor$setbottomcolor$setspace";
			$s = (
			 ($settopcolor eq 't' ? "": "$D{$x}{$y}" )
			.($setbottomcolor eq 'b'? "": "$D{$x}{$y+1}" )
			.($setspace eq 'S'?" ":$LOWER));
		}else{
			$s = "$D{$x}{$y}$D{$x}{$y+1}$LOWER";
		}
		print $s;
		print FOUT $s if($outputfile);
	}
	say restore();

	print FOUT restore(). '"'."\n" if($outputfile);	
}
if($outputfile){
	if($zlib){
		$cmd=`gzip $outputfile`;
		print $cmd if $verbose;
	}
	say `ls -la ${outputfile}*` if $verbose;
}



# Convert RGB to TrueColor Ansicode
sub fg{
	my($r,$g,$b) = @_;
	return "\x1b[38;2;${r};${g};${b}m"
}

sub bg{
	my($r,$g,$b) = @_;
	return "\x1b[48;2;${r};${g};${b}m"
}

# Convert RGB to RGB256 colorspace Ansicode
sub fg256{
	my($r,$g,$b) = @_;
	return "\x1b[38;5;".rgbToAnsi256($r,$g,$b)."m"
}

sub bg256{
	my($r,$g,$b) = @_;
	return "\x1b[48;5;".rgbToAnsi256($r,$g,$b)."m"
}

# Remove all colors and restore terminal
sub restore{
	return "\x1b[0m";
}

# https://github.com/Qix-/color-convert/blob/427cbb70540bb9e5b3e94aa3bb9f97957ee5fbc0/conversions.js#L555-L580
sub rgbToAnsi256 {
	my($r,$g,$b) = @_;
	
    # we use the extended greyscale palette here, with the exception of
    # black and white. normal palette only has 4 greyscale shades.
    if ($r == $g && $g == $b) {
        return 16 if ($r < 8);
        return 231 if ($r > 248);
        return Mathround((($r - 8) / 247) * 24) + 232;
    }

    my $ansi = 16
        + (36 * Mathround($r / 255 * 5))
        + (6 * Mathround($g / 255 * 5))
        + Mathround($b / 255 * 5);

    return $ansi;
}

# Too lazy to add Math.round lib
sub Mathround{
	return int($_[0]+0.5);
	# in case of negative numbers:
	# my $rounded = int($float + $float/abs($float*2 || 1));
}

sub usage {
	print "$_" while (defined($_=<DATA>)) && !/__END__/;
	exit 0;
}

__DATA__
image2ascii.pl  - Convert an image, using ImageMagick to an ANSI colour image, 
which can be printed on a terminal. It does this by printing Unicode Character 
'LOWER HALF BLOCK' and grab 2 pixel rows to use as foreground and background color.

./image2ascii.pl <-i inputfile> [-o outputfile] [-r] [-c] [-z] [-v] [-w width]
 -i: inputfile (any non transparant image that convert can use)
 -w: Resize using width only (keeps aspect ratio). Use x16 for resized height
 -o: Optional outputfile
 -r: Use an RGB256 color palette. The default is TrueColor
 -c: Try to use less ANSI control characters resulting in a smaller file
 -z: Optionally gzip the outputfile.
 -x: Optional string to pass extra parameters to convert.
 -v: Verbose (use twice for more output)

A gzipped outputfile can be displayed using:  zcat outfile.ascii.gz  |bash -C

Dependencies: Uses "convert" from ImageMagick. Uses gzip (if -z is used). uses tr

Usage Example:

# Dump the example rose image from ImageMagick:
convert rose: rose.png
# Display it in TrueColor ANSI:
./image2ascii.pl -i rose.png -w 100%
# If that did not display, use 256 colors instead:
reset; ./image2ascii.pl -i rose.png -w 50% -r

__END__
