#!/usr/bin/perl

# read NMEA data,
# see http://www.nmea.de/nmea0183datensaetze.html#gsv
# extract Satellite view data
# and plot div stuff 
# Wolfgang Rosner
# wrosner@tirnet.de
# provided "as is", don`pay me but don`t sue me...
##
# call like this:
# ./plot-CNR-from-GPGSV.pl  log-2013-02-16-23-16.nmea


use warnings;
use strict;

use Time::Local 'timegm_nocheck' ;	# tiny but what I need
use Data::Dumper ;
# use Math::Interpolate qw(linear_interpolate robust_interpolate);
use Math::Spline;

# in a data base, this might be tables
my @data =();	# collection of pointers to all sv x time data
my %times =(); 	# pointer to arrays of all data for each time
my @svs =();	# count number of data for each sv


# read input file name from cmd line 

my $infile = $ARGV[0] or die ("usage: $0 someinputfile.name");
open INFILE , $infile or die ("cannot read from input file named $infile");

printf ("parsing input file %s\n",  $infile);

# read input file
while(<INFILE>) {
	# print $_;
	chomp ; chop ; #  looks like chomp removes NL but leaves CR 

	# parse GSV lines
	if( /^\$G([NPLBAQ])(\w{3}),(.*)(\*..)$/  ) { 
	
		my @fields = split (',' , $3);
		my @current;

		if($2 eq 'RMC') {
			print ("RMC-record: ");
                        my $hh = substr($fields[0], 0, 2);
                        my $mm = substr($fields[0], 2, 2);
                        my $ss = substr($fields[0], 4, 2);
			my $ms = ( ( "0" . substr($fields[0], 6) ) * 1000);

                        my $dd = substr($fields[8], 0, 2);
                        my $MM = substr($fields[8], 2, 2);
                        my $yy = substr($fields[8], 4, 2) + 2000 ;

			my $timestamp = timegm_nocheck($ss,$mm,$hh,$dd,$MM-1,$yy);

                        # insert timestamp into all SV collected
                        foreach my $svc (@current) {
                                $svc->[0] = $timestamp;
				$svs[ $svc->[1] ] ++; 	# count data per satellite
                        }

			# append all data of current epoch and keep number of records
			push (@data , @current) ;
			$times{$timestamp} = @current ; 
                        # print Dumper(@current);


		}
		elsif ($2 eq 'GSV') {
                        # print ("GSV-record: ");

			# http://www.nmea.de/nmea0183datensaetze.html#gsv 
			#  1) total number of messages
			#  2) message number
			#  3) satellites in view
			#  4) satellite number
			#  5) elevation in degrees
			#  6) azimuth in degrees to true
			#  7) SNR in dB
			#  more satellite infos like 4)-7)

			my $msg_tot = shift @fields;
			my $msg_num = shift @fields;
			my $sat_inV = shift @fields;

			if ( $msg_num == 1 ) {
				@current =() 	# start a new sequence
			}	
			
			while ( @ fields) {
				my $svn = shift @fields;
				my $ele = shift @fields // -1;	# need Perl > 5.10 for // "defined or"
				my $azi = shift @fields // -1;
				my $snr = shift @fields // -1;
				### printf ("sat no %i elevation %i azimuth %i SNR %i\n", $svn, $ele, $azi, $snr); 
				push (@current, [0, $svn, $ele, $azi, $snr ] );
			}
                        ### print ("\n");
		}
	} else {

		printf "================== parse error ============ \n";
		printf  ">>>$_<<<";
		print "\n";
	}



}

close INFILE;

#===============================================================================
# debug print: show what we have now:
print "======================== read complete =======================\n";
print " ... rearranging data ... \n";

print Dumper([@data]);
print "--------------------------------------\n";
print Dumper([%times]);
print "--------------------------------------\n";
print Dumper([@svs]);
print "--------------------------------------\n";

# create data structure for each satellite 

my @sv_time = ();
my @sv_ele = ();
my @sv_azi = ();
my @sv_snr = ();



foreach my $SV (1 .. @svs) {
	# print "SV number ", $SV, " ";
	if (my $hits = $svs[$SV]) {
		print "datapoints: " , $hits;
	}
	# print "\n";
        $sv_time[$SV] = [];
	$sv_ele[$SV] = [];
	$sv_azi[$SV] = [];
	$sv_snr[$SV] = [];
}

# hmmm whatever we do we need all our data in matching arrays
# we like to keep them in higher level arrays by satelite number...

# print Dumper([@sv_time]);

foreach my $datapoint(@data) {
  my $svn = $datapoint->[1];
  # print "svn: ", $svn , " Datapoint: ", join ("|", @$datapoint) , "\n" ;
  push @{$sv_time[$svn]}, ($datapoint->[0]);
  push @{$sv_ele[$svn]} , ($datapoint->[2]);
  push @{$sv_azi[$svn]} , ($datapoint->[3]);
  push @{$sv_snr[$svn]} , ($datapoint->[4]);

}

# print Dumper([@sv_ele]);
# print Dumper([@sv_snr]);

# print Dumper([@sv_ele[12]]);
# print Dumper([@sv_snr[12]]);

#==============================================================================================
# interpolate AZI and ELE between integer jumps
print "inerpolating AZI and ELE...\n";


my @sv_azi_st = ();
my @sv_azi_sa = ();
my @sv_azi_ip = ();

my @sv_ele_st = ();
my @sv_ele_se = ();
my @sv_ele_ip = ();


foreach my $SV (1 .. @svs) {
	if (! (my $hits = $svs[$SV])) { next ; }
	
	# arrays to collect support points
	$sv_azi_st[$SV] = [];
	$sv_azi_sa[$SV] = [];
	$sv_azi_ip[$SV] = [];

	$sv_ele_st[$SV] = [];
	$sv_ele_se[$SV] = [];
	$sv_ele_ip[$SV] = [];

	# my $last_ta = $sv_time[$SV][0];
	my $last_aa = $sv_azi[$SV][0];
	# my $last_te = $sv_time[$SV][0];
	my $last_ee = $sv_ele[$SV][0];

	# search support point at jumps of azi / ele values
	foreach my $i (1..$#{$sv_time[$SV]}) {
		if ($last_aa != $sv_azi[$SV][$i]) {
			# azi step found
			push @{$sv_azi_st[$SV]}, ( 0.5 * ($sv_time[$SV][$i-1] + $sv_time[$SV][$i])) ;
			push @{$sv_azi_sa[$SV]}, ( 0.5 * ($last_aa + $sv_azi[$SV][$i])) ;
			# $last_ta = $sv_time[$SV][$i];
			$last_aa = $sv_azi[$SV][$i];
		}
		if ($last_ee != $sv_ele[$SV][$i]) {
			# ele step found
			push @{$sv_ele_st[$SV]}, ( 0.5 * ($sv_time[$SV][$i-1] + $sv_time[$SV][$i])) ;
			push @{$sv_ele_se[$SV]}, ( 0.5 * ($last_ee + $sv_ele[$SV][$i])) ;
			# $last_te = $sv_time[$SV][$i];
			$last_ee = $sv_ele[$SV][$i];
		}
	}

	# always add start and end points
	push @{$sv_azi_st[$SV]}, $sv_time[$SV][-1] ;
	push @{$sv_azi_sa[$SV]}, $sv_azi[$SV][-1] ;
	unshift @{$sv_azi_st[$SV]}, $sv_time[$SV][0] ;
	unshift @{$sv_azi_sa[$SV]}, $sv_azi[$SV][0] ;

	push @{$sv_ele_st[$SV]}, $sv_time[$SV][-1] ;
	push @{$sv_ele_se[$SV]}, $sv_ele[$SV][-1] ;
	unshift @{$sv_ele_st[$SV]}, $sv_time[$SV][0] ;
	unshift @{$sv_ele_se[$SV]}, $sv_ele[$SV][0] ;


	# now use the spline
	# printf "---------- SV %d", $SV;
	# print Dumper([@sv_azi_st[$SV]]);
	# print Dumper([@sv_azi_sa[$SV]]);
	# print Dumper([@sv_ele_st[$SV]]);
	# print Dumper([@sv_ele_se[$SV]]);
	
	my $spline_az = new Math::Spline(\@{$sv_azi_st[$SV]}, \@{$sv_azi_sa[$SV]});
	my $spline_el = new Math::Spline(\@{$sv_ele_st[$SV]}, \@{$sv_ele_se[$SV]});

	foreach my $i (1..$#{$sv_time[$SV]}) {
		$sv_azi_ip[$SV][$i] = $spline_az->evaluate($sv_time[$SV][$i]);
		$sv_ele_ip[$SV][$i] = $spline_el->evaluate($sv_time[$SV][$i]);
	}
}

#==============================================================================================

print "====== calling gnuplot =========\n";

my $gnuplot = "/usr/bin/gnuplot";

#### build temporary folder and file name structure
# separate path/basename.extension
(my $pathbase = $infile)   =~ s{\.[^.]+$}{}; # removes extension
(my $basename = $pathbase) =~ s{.*/}{};      # removes path

printf("basename: >>%s<<, pathbase >>%s<<, infile: >>%s<<\n",   $basename , $pathbase , $infile);

# create a dir named pathase, append sequential number if already exists
my $tempfile_dir = $pathbase;
my $i = 0;
while (-d $tempfile_dir) {
	$i++;
	$tempfile_dir = sprintf("%s_%d", $pathbase, $i);
}

mkdir $tempfile_dir;

my $tempfile_prefix = sprintf("%s/%s", $tempfile_dir, $basename);
printf("dir: %s ; prefix: %s\n", $tempfile_dir , $tempfile_prefix);

# $tempfile_body = $tempfile_prefix . $time_suffix;
my $tempfile_body = $tempfile_prefix;


my $templog  = $tempfile_body . '.log';
my $tempcmd  = $tempfile_body . '.gnu';

# for combined data output .. still to do
my $temppng_all  = $tempfile_body . '_all.png';		# rectangle plot of all sats
# $temppng_sky  = $tempfile_body . '_sky.png';		# polar skyplot color coded
# $tempdata_all = $tempfile_body . '_all.data';

# header for all SV on top of each other
my $command_all = <<ENDOFCMDALL;
#  all SNR over elev scatter on top of each other
set term png
set output "$temppng_all"
set xrange [0:90]
set yrange [-1:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
set multiplot
ENDOFCMDALL

# animated GIF with all SV in sequence
my $tempgif_anim  = $tempfile_body . '_anim.gif';

my $command_anim = <<ENDOFCMDANIM;
# animated gif for all SNR over elev scatter
set term  gif animate opt delay 100
set output "$tempgif_anim"
set xrange [0:90]
set yrange [-1:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
ENDOFCMDANIM

# elevation by time
my $temppng_et = $tempfile_body . '_et.png';

my $command_et = <<ENDOFCMDET;
# elevation over time by SV
set term png
set output "$temppng_et"
set yrange [-1:90]
set multiplot
set xdata time
set timefmt "%s"
set format x "%H:%M"
set xrange [$data[0][0]-946684800:$data[-1][0]-946684800]
set ylabel 'Elevation in deg'
ENDOFCMDET

# polar skyplot color coded
my $tempdata_sky  = $tempfile_body . '_sky.data';	
my $temppng_sky  = $tempfile_body . '_sky.png';		

open (SKYDATA, ">".$tempdata_sky) || error ("could not create temp data file $tempdata_sky");


foreach my $SV (1 .. @svs) {
        my $hits;
	if (! ( $hits = $svs[$SV])) { next ; }


	my $temppng_sv  = sprintf ("%s_%03d.png", $tempfile_body , $SV);
	my $tempdata_sv = sprintf ("%s_%03d.data", $tempfile_body , $SV);

	printf ("writing data for SV# %d with %d data points ... ", $SV, $hits);

	open (DATAFILE, ">".$tempdata_sv) || error ("could not create temp data file $tempdata_sv");

	foreach my $i (0..$#{$sv_time[$SV]}) {
		printf DATAFILE ("%f %f %f %f %f %f\n", 
			$sv_time[$SV][$i] ,
			$sv_ele[$SV][$i] ,
			$sv_azi[$SV][$i] ,
			$sv_snr[$SV][$i] ,
			$sv_ele_ip[$SV][$i] ,
			$sv_azi_ip[$SV][$i] 
		);
		
		# convert polar data for skyplot
		printf 	SKYDATA ("%s %s %s\n",
			# polar2xy ( angle, radius) ; angle in deg
			# azimuth counts clockwise, elevation from zenith down
			polar2xy(-$sv_azi[$SV][$i], 90 - $sv_ele[$SV][$i]),
			$sv_snr[$SV][$i] 
		);
	}

	close DATAFILE || error ("could not close temp data file $tempdata_sv");

	print SKYDATA "\n" ;	# does an empty line seperate curves??

	printf ("creating chart for SV# %d....\n", $SV);

	# create single plot for each SV	 
	my $command= <<ENDOFCOMMAND;
# plot for SV # $SV
set term png
set output "$temppng_sv"
set xrange [0:90]
set yrange [-1:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
plot "$tempdata_sv" using 2:4 with points lt $SV

ENDOFCOMMAND

	gnuplotcmd($command);


	# add entry for multi SV scatter plot
	$command_all .= "plot \"$tempdata_sv\" using 2:4 with points lt $SV\n";

	# add entry for multi SV animated gif
	$command_anim .= "plot \"$tempdata_sv\" using 2:4 with points lt $SV\n";
	
	# add entry for elevation  over time
	$command_et .= "plot \"$tempdata_sv\" using 1:2 with lines lt $SV\n";
	$command_et .= "plot \"$tempdata_sv\" using 1:5 with lines lt $SV\n";
}

close SKYDATA;

print "rendering skyplot\n";
my $command_sky = <<ENDOFCMDSKY;
# skyplot of SNR vs polar elevation/azimuth
set term png
set output "$temppng_sky"
set size square
set view 0 , 270 , 1.5 ,1
unset border
unset tics
set cbtics
set cbrange[20:60]
set palette defined (20 "blue", 40 "green", 45 "yellow", 55 "red", 60 "#ffaaaa" )
splot "$tempdata_sky" u 1:2:3 w p lc palette pt 7
ENDOFCMDSKY

gnuplotcmd($command_sky);

print "rendering combined plot\n";
# render the combined plot
gnuplotcmd($command_all);

print "rendering animated gif plot\n";
# render animated gif
gnuplotcmd($command_anim);

print "rendering elevation over time\n";
# render animated gif
gnuplotcmd($command_et);


#=========================================================================0
print "collecting statistical values\n";
# we might initialize arrays like
#	@foo = map {[ (0) x $x ]} 1 .. $y

my @sv_ele_V_cnt = map {[ (0) x 90 ]} (1 .. @svs) ; 
my @sv_ele_V_sum = map {[ (0) x 90 ]} (1 .. @svs) ;
my @sv_ele_V_sum2sq = map {[ (0) x 90 ]} (1 .. @svs) ;

# collect each sv  x elev-1-deg interval
foreach my $dp(@data) {
	my $svn = $dp->[1];
	my $ele = $dp->[2];
	my $snr = $dp->[4];

	unless ( $snr > 0 ) {	next ; } 	# exclude 0 and -1 SNR values
	
	$sv_ele_V_cnt[$svn][$ele] ++ ;		# count occurances
	$sv_ele_V_sum[$svn][$ele] += $snr ;		# sum
	$sv_ele_V_sum2sq[$svn][$ele] += $snr * $snr ;	# sum of squares
}


my @sv_cnt =();
my @sv_cnt_sum =();
my @sv_sum_sum =();
my @sv_sum2sq_sum =();

my $svs_cnt;
my $sv_x_ele_cls;
my $sv_x_ele_cnt;
my $sv_x_ele_sum;
my $sv_x_ele_sum2sq;

# aggregates over satellites
foreach my $sv(1 .. @svs) {
	unless ((my $hits = $svs[$sv])) { next ; }
	foreach my $ele (0 .. 90 ) {
		unless ( $sv_ele_V_cnt[$sv][$ele] ) { next ; }
		$sv_cnt[$sv] ++;	# number of elev intervals in track
		$sv_cnt_sum[$sv] += $sv_ele_V_cnt[$sv][$ele];
		$sv_sum_sum[$sv] += $sv_ele_V_sum[$sv][$ele];
		$sv_sum2sq_sum[$sv] += $sv_ele_V_sum2sq[$sv][$ele];
	}
	$svs_cnt ++ ;		# number of SVs with data
	$sv_x_ele_cls += $sv_cnt[$sv];	# number of classes
	$sv_x_ele_cnt += $sv_cnt_sum[$sv];  # number of datapoints
	$sv_x_ele_sum += $sv_sum_sum[$sv];
	$sv_x_ele_sum2sq += $sv_sum2sq_sum[$sv];
}


my @ele_cnt =();
my @ele_cnt_sum =();
my @ele_sum_sum =();
my @ele_sum2sq_sum =();

my $elevs_cnt;
my $ele_x_sv_cls;
my $ele_x_sv_cnt;
my $ele_x_sv_sum;
my $ele_x_sv_sum2sq;


# aggregates over elev intervals
foreach my $ele (0 .. 90 ) {
	# no obvious skip condition?
	foreach my $sv(1 .. @svs) {
		# if (! ($hits = $svs[$sv])) { next ; }
		unless ( $sv_ele_V_cnt[$sv][$ele] ) { next ; }

		$ele_cnt[$ele] ++;	# number sv in this elev interval
		$ele_cnt_sum[$ele] += $sv_ele_V_cnt[$sv][$ele];
		$ele_sum_sum[$ele] += $sv_ele_V_sum[$sv][$ele];
		$ele_sum2sq_sum[$ele] += $sv_ele_V_sum2sq[$sv][$ele];
	}
	$elevs_cnt ++ ;		# number of elevs with data
	$ele_x_sv_cls += $ele_cnt[$ele];  # number of classes
	$ele_x_sv_cnt += $ele_cnt_sum[$ele]; # number of datapoints
	$ele_x_sv_sum += $ele_sum_sum[$ele];
	$ele_x_sv_sum2sq += $ele_sum2sq_sum[$ele];
}

# overall aggregates
printf ("SVs: %d, classes: %d, samples %d, sum %d , sum-square: %d\n",
	 $svs_cnt, $sv_x_ele_cls, $sv_x_ele_cnt, $sv_x_ele_sum, $sv_x_ele_sum2sq );

printf ("ele: %d, classes: %d, samples %d, sum %d , sum-square: %d\n",
	$elevs_cnt, $ele_x_sv_cls, $ele_x_sv_cnt, $ele_x_sv_sum, $ele_x_sv_sum2sq );

my $overall_mean_snr = $ele_x_sv_sum / $ele_x_sv_cnt;
my $overall_varc_snr = ($ele_x_sv_sum2sq - ($ele_x_sv_sum * $ele_x_sv_sum / $ele_x_sv_cnt))  /
					($ele_x_sv_cnt-1) ;
my $overall_stdev_snr = sqrt($overall_varc_snr);

printf ("overall mean: %f; variance: %f;  stddev: %f", 
	$overall_mean_snr, $overall_varc_snr, $overall_stdev_snr);


# ----------------  calculating and writing plottables

# standard dev over all satellites per elevation
my $tempdata_sdev = $tempfile_body . '_sdev.data';
my $temppng_sdev = $tempfile_body . '_sdev.png'; 

open (SDEVDATA, ">".$tempdata_sdev) || error ("could not create temp data file $tempdata_sdev");

my @ele_mean = ();
my @ele_varc = ();
my @ele_stdev = ();



foreach my $ele (1 .. 90 ) {
	unless ($ele_cnt_sum[$ele] > 1) { next ; }

	$ele_mean[$ele] = $ele_sum_sum[$ele] / $ele_cnt_sum[$ele] ;
	$ele_varc[$ele] = ($ele_sum2sq_sum[$ele] - ($ele_sum_sum[$ele] * $ele_sum_sum[$ele]  /
		 $ele_cnt_sum[$ele]))  /  ($ele_cnt_sum[$ele]-1) ;
	$ele_stdev[$ele] = sqrt($ele_varc[$ele]);

	printf SDEVDATA ("%d %f %f %f\n", $ele,
		 $ele_mean[$ele], $ele_varc[$ele], $ele_stdev[$ele]);
}

close SDEVDATA;


my $command_sdev = <<ENDOFCMDSDEV;
# plot standard dev over all satellites per elevation
set term png
set output "$temppng_sdev"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
set multiplot
plot "$tempdata_sdev" using 1:2 w lines lw 3
plot "$tempdata_sdev" using 1:2:4 w yerrorbars

ENDOFCMDSDEV

gnuplotcmd($command_sdev);


# standard dev over elevation for each sv
 
my @sv_mean_snr = ();
my @sv_varc_snr = ();
my @sv_stdev_snr = ();

my @sv_ele_mean = ();
my @sv_ele_varc = ();
my @sv_ele_stdev = ();


foreach my $sv(1 .. @svs) {
	unless ($sv_cnt_sum[$sv] > 1) { next ; }

	$sv_mean_snr[$sv] = $sv_sum_sum[$sv] / $sv_cnt_sum[$sv] ;
	$sv_varc_snr[$sv] = ($sv_sum2sq_sum[$sv] - ( $sv_sum_sum[$sv] * $sv_sum_sum[$sv] / 				$sv_cnt_sum[$sv])) /	($sv_cnt_sum[$sv]-1) ;
	$sv_stdev_snr[$sv] = sqrt($sv_varc_snr[$sv]);

	printf ("statiscs for SV ' %3d: mean: %9f; variance: %9f; stddev: %9f",
		$sv, $sv_mean_snr[$sv], $sv_varc_snr[$sv] , $sv_stdev_snr[$sv]);

	my $temppng_sv_sdev = sprintf ("%s_sdev_%03d.png", $tempfile_body , $sv);
	my $tempdata_sv_sdev = sprintf ("%s_sdev_%03d.data", $tempfile_body , $sv);

	printf ("   ... writing data ... \n");

	open (SVSDEVDATA, ">".$tempdata_sv_sdev) || 
			error ("could not create temp data file $tempdata_sv_sdev");

	foreach my $ele (1 .. 90 ) {
		unless ($sv_ele_V_cnt[$sv][$ele] > 1) { next ; }

		$sv_ele_mean[$sv][$ele] = $sv_ele_V_sum[$sv][$ele] / $sv_ele_V_cnt[$sv][$ele] ;
		$sv_ele_varc[$sv][$ele] = ( $sv_ele_V_sum2sq[$sv][$ele] -
			( $sv_ele_V_sum[$sv][$ele] * $sv_ele_V_sum[$sv][$ele] /
			$sv_ele_V_cnt[$sv][$ele] )) / ( $sv_ele_V_cnt[$sv][$ele]- 1) ;
		$sv_ele_stdev[$sv][$ele] = sqrt($sv_ele_varc[$sv][$ele]);

		printf SVSDEVDATA ("%d %f %f %f\n", $ele,
		$sv_ele_mean[$sv][$ele], $sv_ele_varc[$sv][$ele], $sv_ele_stdev[$sv][$ele]);
	}

	close SVSDEVDATA;

	my $command_sv_sdev = <<ENDOFCMDSVSDEV;
# plot standard dev over all satellites per elevation
set term png
set output "$temppng_sv_sdev"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
set multiplot
plot "$tempdata_sv_sdev" using 1:2 w lines lw 3 lt $sv
plot "$tempdata_sv_sdev" using 1:2:4 w yerrorbars lt $sv
ENDOFCMDSVSDEV

	gnuplotcmd($command_sv_sdev);
	
}


print " ======= DONE ==========\n";
exit ;
###################################################################
sub error {
        my ($errmessg) = @_;
        die ("Error: " . $errmessg );
}

# cave: global vars $tempcmd, $gnuplot !
sub gnuplotcmd {
	my ($cmd) = shift(@_);

	open CMDLOG, ">>", "$tempcmd" || error ("cannot open $tempcmd")   ;
	print CMDLOG $cmd;
	print CMDLOG "\n";
	close CMDLOG ; 

	open GNUPLOT, "| $gnuplot > $templog 2>&1" || error ("cannot open gnuplot")   ;
	print GNUPLOT $cmd    || error ("cannot send data to gnuplot") ;
	close GNUPLOT ;   

}

# polar2xy ( angle, radius) ; angle in deg
sub polar2xy {
	use constant PI => (4 * atan2 (1, 1));
	my ($angle, $radius) = @_;
	my $x = $radius * cos ( $angle * PI/180);
	my $y = $radius * sin ( $angle * PI/180);
	return($x, $y);
}
