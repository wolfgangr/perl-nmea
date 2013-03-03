#!/usr/bin/perl
#
# calculation of reverse holgoram using aggregated skyplot data as input
#

use Math::Complex; #':pi' ;	# hope this does'nt hurt performacne .... 
use Data::Dumper;

# use constant PI    => 4 * atan2(1, 1); # pi is defined in Math::Complex

@x_range = (-10..10);		# +x -> North
@y_range = (-10..10);		# +y -> East
@z_range = (-5..5);		# +z -> up ... ?? or should we follow right hand rule??

$x_ant = 0;			# where antenna is located in above interval
$y_ant = 0;
$z_ant = 0;

$x_step = 0.1;			# x interval per voxel in m
$y_step = 0.1;
$z_step = 0.1;

$lambda = 3e8 / 1575e6 ;	# wave lenght 300000000/1575000000
$dB1 = 30;			# dB value which is mapped to 1
$scale = 0.001;		# rescaler to avoid numerical overflow etc

# ========== END OF CONFIG =======================



$infile = $ARGV[0] or die ("usage: $0 input file");


$x_min = ($x_range[0]  - $x_ant) * $x_step;
$x_max = ($x_range[-1] - $x_ant) * $x_step;

$y_min = ($y_range[0]  - $y_ant) * $y_step;
$y_max = ($y_range[-1] - $y_ant) * $y_step;

$z_min = ($z_range[0]  - $z_ant) * $z_step;
$z_max = ($z_range[-1] - $z_ant) * $z_step;

printf ("target interval  x:(%s..%s), y:(%s..%s), z:(%s..%s) m\n",
	$x_min, $x_max, $y_min, $y_max, $z_min, $z_max );

printf ("\tlambda = %f\n", $lambda);


# initialize result space
#	$voxels[$x][$y][$z] with complex zeros
# my @matrix=map [(0)x5], 0..4;
# my @matrix;
# push @matrix, [(0)x5] for (0..4);

@voxels =();

foreach (@x_range) {
	# my @x_plane = map[ cplx(0,0) x ($#y_range-1) ] , 0..($#z_range-1) ;
	my @x_plane =();
	foreach (@y_range) {
		my @xy_line = map[ cplx(0,0) ] , 0..($#z_range) ;
		push @x_plane, \@xy_line;
	}
	push @voxels , \@x_plane;
}

# print Dumper(@voxels);

# ================================
# while reading input line by line, do the real hard work

open (INFILE, $infile) || die ("cannot read from file $infile");
	while (<INFILE>) {
		print $_;
		# eg 34.255548 100.524229 20 2
		# elevation, azimuth, snr, repeats
		@inlist = split ; #  ($_);
		# print (join ("|", @inlist ), "\n");
		unless ($#inlist == 3) { die ("format of $infile does not match"); }
		# die ("cutting edge");
		my ($ele, $azi, $snr, $repeats) = @inlist;
		my $amplitd = $scale * $repeats * (10 ** (($snr - $dB1) / 10) ) ;

		my $ele_rad = $ele * pi / 180;
		my $azi_rad = $azi * pi / 180;

		# wave number counts between adjacent voxels in each direction
		my $x_wcnt = ($x_step / $lambda) * cos($ele_rad) * cos($azi_rad);
		my $y_wcnt = ($y_step / $lambda) * cos($ele_rad) * sin($azi_rad);
		my $z_wcnt = ($z_step / $lambda) * sin($ele_rad) ;

		printf( "%s %s %s %s %s %s\n", $amplitd, $ele_rad,  $azi_rad ,
			$x_wcnt, $y_wcnt, $z_wcnt ) ;

		# the complex wave step factors of size 1;
		my $x_wstp = cplxe(1, pi * 2 * $x_wcnt);
		my $y_wstp = cplxe(1, pi * 2 * $y_wcnt);
		my $z_wstp = cplxe(1, pi * 2 * $z_wcnt);

		# printf ("x: %s | y: %s | z: %s \n", $x_wstp,  $y_wstp, $z_wstp) ;
		# printf Dumper([$x_wstp,  $y_wstp, $z_wstp]) ;


		# enforce cartesification, should be tested for performance effect...
		# $x_wstp->display_format('cartesian');
		# $y_wstp->display_format('cartesian');
		# $z_wstp->display_format('cartesian');

		# printf ("x: %s | y: %s | z: %s \n", $x_wstp,  $y_wstp, $z_wstp) ;
		# printf Dumper([$x_wstp,  $y_wstp, $z_wstp]) ;

		# start of wavefront phase at bottom corner
		my $x_phase = $x_wstp ** $x_range[0] +	
			$y_wstp ** $y_range[0] + $z_wstp ** $z_range[0] ;


		foreach my $ix (0..$#x_range) {
			my $x = $x_range [$ix] ;

			my $xy_phase = $x_phase;
			foreach my $iy (0..$#y_range) {
				my $y = $y_range [$iy] ;

				my $xyz_phase = $xy_phase;
				foreach my $iz (0..$#z_range) {
					my $z = $z_range [$iz] ;
					printf ("x: %s -> %s, y: %s -> %s z: %s -> %s\n",
						$ix, $x, $iy, $y, $iz, $z);

					# here it is going to happen:
					$voxels[$x][$y][$z] += $xyz_phase * $amplitd;
		die ("#============~~~~~~~~~~~~~~~~---------- <- cutting edge 0\n");
					$xyz_phase *= $z_wstp;
				} 
				$xy_phase *= $y_wstp;
			} 
			$x_phase *= $x_wstp;
		}
		die ("#============~~~~~~~~~~~~~~~~---------- <- cutting edge I\n");
	}
close INFILE;

die ("#============~~~~~~~~~~~~~~~~---------- <- cutting edge II\n");

# =========================================

(my $pathbase = $infile)   =~ s{\.[^.]+$}{}; # removes extension
my $outfile = sprintf ("%s.voxels", $pathbase);

open (OUTFILE, ">".$outfile) || die ("cannot write to file $outfile");



close OUTFILE;


