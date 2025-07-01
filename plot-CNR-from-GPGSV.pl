#!/usr/bin/perl

# read NMEA data,
# see http://www.nmea.de/nmea0183datensaetze.html#gsv
# extract Satellite view data
# and plot div stuff 
# refactored 2025 for multi SYS, multi band NMEA 4.whatever
#
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
# use Math::Spline;

use Devel::Size qw(size total_size);
use Readonly;

# Table 7-1 Satellite Systems and Abbreviations
Readonly my @systems_tags => qw(Multi GPS GLONASS Galileo BDS QZSS IRNSS);
Readonly my @systems_ltr  => qw(N      P   L       A      B   Q    I);
Readonly my %systems => map { $systems_ltr[$_] => { 
    letter => $systems_ltr[$_],
    tag    => $systems_tags[$_],
    idx    => $_
  }    } (0 .. $#systems_ltr);

# Table 7-34 GNSS ID
Readonly my @sigids => ( [],
	[ qw(all L1_CA L1_PY L1_M L2_PY L2C-M L2C-L L5-I L5-Q) ],
	[ qw(all G1_CA G1_P       G2_CA G2_P) ],
	[ qw(all E5a E5b E5ab E6A E6BC L1A L1BC ) ],
	[ qw(all B1I B1Q B1C B1A B2a B2b B2ab B3I B3Q B3A B2I B2Q ) ],
	[ qw(all L1CA L1CD L1CP LIS L2CM L2CL L5I L5Q L6D L6E ) ],
	[ qw(all L5_SPS S_SPS L5_RS S_RS L1_SPS ) ]
  );

# https://de.wikipedia.org/wiki/Globales_Navigationssatellitensystem#/media/Datei:Gnss_bandwidth.svg
# https://gssc.esa.int/navipedia/images/c/cf/GNSS_All_Signals.png
# ... cum grano salis ...
# TODO: update and cross-check

Readonly my @sig_freqs => ( [],
	[ 0, (1575.42) x 3, (1227.6) x 3, (1176.45) x 2 ],
	[ 0, (1602) x 2, (1246) x 2],
	[ 0, (1191.8) x 3, (1278.75) x 2, (1575.42) x 2 ],
	[ 0, (1575.42) x 4, (1191.8) x 3, (1268.52) x 3 , (1207.14) x 2 ],
	[ 0, (1575.42) x 4, (1227.6) x 2, (1176.45) x 2 , (1278.75) x 2 ],
	[ 0, (1176.45) x 4 , 1575.42 ]	
);

# mainly for crosschecking
my %SIG_TABLE;
my @SIG_TABLE_ary;

for my $sys_idx (0 .. $#systems_ltr) {
  my %sys_plan;
  my @sys_plan_ary =();
  my $sys_tag = $systems_tags[$sys_idx];

  for my $sig_idx (0 .. $#{$sigids[$sys_idx]} ) {
    # print $sys_idx, '-', $sig_idx, "\n";
    my $sig_tag = $sigids[$sys_idx][$sig_idx];
    my $sig_frq = $sig_freqs[$sys_idx][$sig_idx];
    $sys_plan{$sig_tag} = { 
      sys_idx => $sys_idx,
      sys_tag => $sys_tag,
      sig_idx => $sig_idx,
      sig_tag => $sig_tag,
      frequ   => $sig_frq
    } ;
    push @sys_plan_ary, $sys_plan{$sig_tag};
  }
  $SIG_TABLE{$sys_tag} = \%sys_plan;
  push @SIG_TABLE_ary, \@sys_plan_ary;
}

# print Dumper (\%SIG_TABLE);
# print Dumper (\@SIG_TABLE_ary);
# exit;
# print Dumper (\%systems);
# print Dumper (\@sigids);
# print Dumper (\@sig_freqs);
# exit;

# read input file name from cmd line ==================================================================

my %SVS_cnt = ();   # keep SV sys and sig IDs
my %time_dat =();   # new data structure

my $infile = $ARGV[0] or die ("usage: $0 someinputfile.name");
open INFILE , $infile or die ("cannot read from input file named $infile");
printf ("parsing input file %s\n",  $infile);

# read input file

my $timestamp; # better be "static"?

while(<INFILE>) {
	chomp ; chop ; #  looks like chomp removes NL but leaves CR 

	# parse GSV lines
	if( /^\$G([NPLBAQ])(\w{3}),(.*)(\*..)$/  ) { 
	
		my @fields = split (',' , $3);

		if($2 eq 'GGA') {
                        # insert timestamp into all SV collected
			$timestamp = $fields[0] ;

			# Table 7-4 GGA Data Structure
			#	( N4 Products Commands and Logs Reference Book )
			my %cga = (
				timestamp 	=> $timestamp,
				lat 		=> $fields[1],
				lat_dir		=> $fields[2],
                                lon		=> $fields[3],
                                lon_dir		=> $fields[4],
                                q_fix 		=> $fields[5],
                                n_sats		=> $fields[6],
                                hdop		=> $fields[7],
				age		=> $fields[12]
			); 

			# %time_dat is main data collector
			$time_dat{$timestamp}{cga} = \%cga;
		}

		elsif ($2 eq 'GSV') {
			next unless $timestamp; # skip head until encounter a GNGGA
			# http://www.nmea.de/nmea0183datensaetze.html#gsv 
			#  1) total number of messages
			#  2) message number
			#  3) satellites in view
			#  4) satellite number
			#  5) elevation in degrees
			#  6) azimuth in degrees to true
			#  7) SNR in dB
			#  more satellite infos like 4)-7)

			my $sys_id = $1;
			
			my $msg_tot = shift @fields;
			my $msg_num = shift @fields;
			my $sat_inV = shift @fields;

			my $sig_id = pop @fields;
			
			while ( @ fields) {
				my $svn = shift @fields;
				my $ele = shift @fields // undef;	# need Perl > 5.10 for // "defined or"
				my $azi = shift @fields // undef;
				my $snr = shift @fields // undef;

				# build new data structure
				$SVS_cnt{$sys_id}{$svn}{$sig_id}{count}++;
				$time_dat{$timestamp}{count}++;
				my %dp = (
						timestamp => $timestamp,	
						sys_ltr => $sys_id,
						sys_id  => $systems{$sys_id}->{idx}, 
						svn => int($svn),
						sig => int($sig_id),
					);
				$dp{ele} = int($ele) if $ele;
				$dp{azi} = int($azi) if $azi;
				$dp{snr} = int($snr) if $snr;
				
				push @{ $SVS_cnt{ $dp{sys_id} }{ $dp{svn} }{ $dp{sig} }{data} }, \%dp ; 
				push @{ $time_dat{$timestamp}{data} }, \%dp ;
	
			}
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


if (0) {  # debug block
# exit; # ===~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~---------------------------------------------------

$Data::Dumper::Sortkeys = 1;

print "---\%SVS_cnt-----------------------------------\n";
print Data::Dumper->Dump([\%SVS_cnt], [qw(\%SVS_cnt)] );
print 'length of %SVS_cnt: ', scalar %SVS_cnt, '; ';
print 'size of %SVS_cnt is ', total_size(\%SVS_cnt), "\n";

exit; # ===~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~---------------------------------------------------

print "---\%time_dat-----------------------------------\n";
print Data::Dumper->Dump([\%time_dat], [qw(\%time_dat)] );
print 'length of %time_dat: ', scalar %time_dat, '; ';
print 'size of %time_dat is ', total_size(\%time_dat), "\n";
exit; # ===~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~---------------------------------------------------

}

#=============================================================================================================
# re-indexing systems x sv x sig

my @svs_sorted;  # all combinations
my @svs_sig1;    # only main band per system

for my $sysref (@SIG_TABLE_ary) {
  my $sys_idx = $$sysref[0]->{sys_idx};    # $system->{sys_idx}->{idx};
  next unless defined $sys_idx;
  next unless defined $SVS_cnt{$sys_idx};
  my %system = %{$SVS_cnt{$sys_idx}};
  my $satnum = scalar keys %system ;
  # printf("idx=%d - num sat=%d \n", $sys_idx, $satnum );
  next unless $satnum ;

  for my $sv_idx (sort { $a <=> $b }  keys %system) {
    my @sv_sigs = sort { $a <=> $b }  keys %{ $system{$sv_idx} };

    for my $svsig (@sv_sigs) {
      # array sorted by system / sv / sig -> %entry
      # - SIG_TABLE data
      # - SV number
      # - data from G*GSV sentences
      my %entry = ( %{$$sysref[$svsig] },
		sv_nr => $sv_idx ,
                data => $system{$sv_idx}->{$svsig}->{data}
         );
      push @svs_sorted, \%entry;
      push @svs_sig1, \%entry if ( $svsig == 1 );
    }
  }
}

$Data::Dumper::Sortkeys = 1;
# print Data::Dumper->Dump([\@svs_sorted], [qw(\@svs_sorted)] );
# print Data::Dumper->Dump([\@svs_sig1],   [qw(\@svs_sig1)] );

printf "\@svs_sorted has %d entries\n"  , scalar @svs_sorted;
printf "\@svs_sig1   has %d entries\n"  , scalar @svs_sig1;

if(1) {
  print "sorted Data for Satellites\n";
  for my $entryref (@svs_sorted) {
    printf ("system: %s      \t sv: %d  \t %.1s sig %s \t(%.2f MHz)  \t data points: %d \n",
      $entryref->{sys_tag} , $entryref->{sv_nr}, 
      ($entryref->{sig_idx} ==1) ? '*' : ' ',
      $entryref->{sig_tag}, $entryref->{frequ}, 
      scalar @{ $entryref->{data} } );

  }
}

#exit; 
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

# polar skyplot color coded
my $tempdata_sky  = $tempfile_body . '_sky.data';	
my $temppng_sky  = $tempfile_body . '_sky.png';		


# die("DEBUG cutting edge"); #===============================~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~----------------------------

open (SKYDATA, ">".$tempdata_sky) || error ("could not create temp data file $tempdata_sky");

# my @svs; ### TBD syntax dummy .... to be replaced by new structure

my $lt = 0 ; # gnuplot linetype
foreach my $SVobj (@svs_sorted) {
	# 3 usages of $SV: gnuplot lt aka line type, file name, human readable label
	$lt++; # resemble old $SV behaviour by assigning every combination a new line type
        my $SVstr = sprintf("%s_%03d_%s", $SVobj->{sys_tag}, $SVobj->{sv_nr}, $SVobj->{sig_tag});
	my $SVhstr = sprintf("%s %03d %s", $SVobj->{sys_tag}, $SVobj->{sv_nr}, $SVobj->{sig_tag});
	my @data = @{$SVobj->{data}} ;
	# print Dumper($SVobj);
	# print Dumper(\@data);

	my $temppng_sv  = sprintf ("%s_%s.png", $tempfile_body , $SVstr);
	my $tempdata_sv = sprintf ("%s_%s.data", $tempfile_body , $SVstr);

	printf ("writing data for SV %s with %d data points ... \n", $SVhstr, scalar @data );

	open (DATAFILE, ">".$tempdata_sv) || error ("could not create temp data file $tempdata_sv");

	foreach my $dp (@data ) { # 	i	(0..$#{$sv_time[$SV]}) {
		# print Dumper(\$dp);
		# exit;
		# next unless defined $dp;
		# next unless $dp;
		next unless defined $dp->{timestamp};
		next unless defined $dp->{ele};
		next unless defined $dp->{azi};
		next unless defined $dp->{snr};

		printf DATAFILE ("%s %f %f %f \n", 
			$dp->{timestamp},
			$dp->{ele},
			$dp->{azi},
			$dp->{snr},
	 	     );
		
		# convert data for skyplot
		# (set polar in gnuplot)
		# use only data from sig 1 per sys
		next unless $dp->{sig} == 1;
		printf 	SKYDATA ("%s %s %s\n",
			# polar2xy(-$dp->{azi}, 90 - $dp->{ele}),
			$dp->{azi}, $dp->{ele},
                        $dp->{snr}, 
		);
	}

	close DATAFILE || error ("could not close temp data file $tempdata_sv");

	print SKYDATA "\n" ;	# does an empty line seperate curves??

	printf ("creating chart for SV# %s....\n", $SVhstr);

	# create single plot for each SV	 
	my $command= <<ENDOFCOMMAND;
# plot for SV # $SVhstr
set term png
set output "$temppng_sv"
set xrange [0:90]
set yrange [-1:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
plot "$tempdata_sv" using 2:4 with points lt $lt

ENDOFCOMMAND

	gnuplotcmd($command);


	# add entry for multi SV scatter plot
	$command_all .= "plot \"$tempdata_sv\" using 2:4 with points lt $lt\n";

	# add entry for multi SV animated gif
	$command_anim .= "plot \"$tempdata_sv\" using 2:4 with points lt $lt\n";
	
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

die ("DEBUG after standard plots"); #=========================~~~~~~~~~~~~~~~~~~~~-----------------
my @svs; ### TBD moved dummy
#=========================================================================0
print "collecting statistical values\n";
# we might initialize arrays like
#	@foo = map {[ (0) x $x ]} 1 .. $y

my @sv_ele_V_cnt = map {[ (0) x 90 ]} (1 .. @svs) ; 
my @sv_ele_V_sum = map {[ (0) x 90 ]} (1 .. @svs) ;
my @sv_ele_V_sum2sq = map {[ (0) x 90 ]} (1 .. @svs) ;


my @data; ### TBD syntax dummy -  to be replaced
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
