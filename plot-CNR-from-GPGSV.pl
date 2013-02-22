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


use Time::Local 'timegm_nocheck' ;	# tiny but what I need
use Data::Dumper ;

# in a data base, this might be tables
@data =();	# collection of pointers to all sv x time data
%times =(); 	# pointer to arrays of all data for each time
@svs =();	# count number of data for each sv


# read input file name from cmd line 

$infile = $ARGV[0] or die ("usage: $0 someinputfile.name");
open INFILE , $infile or die ("cannot read from input file named $infile");

printf ("parsing input file %s\n",  $infile);

# read input file
while(<INFILE>) {
	# print $_;
	chomp ; chop ; #  looks like chomp removes NL but leaves CR 

	# parse GSV lines
	if( /\$GP(\w{3}),(.*)(\*..)$/  ) { 
	
		@fields = split (',' , $2);

		if($1 eq 'RMC') {
			### print ("RMC-record: ");
                        my $hh = substr($fields[0], 0, 2);
                        my $mm = substr($fields[0], 2, 2);
                        my $ss = substr($fields[0], 4, 2);
			my $ms = ( ( "0" . substr($fields[0], 6) ) * 1000);

                        my $dd = substr($fields[8], 0, 2);
                        my $MM = substr($fields[8], 2, 2);
                        my $yy = substr($fields[8], 4, 2) + 2000 ;

			$timestamp = timegm_nocheck($ss,$mm,$hh,$dd,$MM-1,$yy);

                        # insert timestamp into all SV collected
                        foreach $svc (@current) {
                                $svc->[0] = $timestamp;
				$svs[ $svc->[1] ] ++; 	# count data per satellite
                        }

			# append all data of current epoch and keep number of records
			push (@data , @current) ;
			$times{$timestamp} = @current ; 
                        # print Dumper(@current);


		}
		elsif ($1 eq 'GSV') {
                        ### print ("GSV-record: ");

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
				my $ele = shift @fields;
				my $azi = shift @fields;
				my $snr = shift @fields;
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

#================
# debug print: show what we have now:
print "======================== read complete =======================\n";
print " ... rearranging data ... \n";

# print Dumper([@data]);
# print "--------------------------------------\n";
# print Dumper([%times]);
# print "--------------------------------------\n";
# print Dumper([@svs]);
# print "--------------------------------------\n";

# create data structure for each satellite 
foreach $SV (1 .. @svs) {
	# print "SV number ", $SV, " ";
	if ($hits = $svs[$SV]) {
		# print "datapoints: " , $hits;
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

foreach $datapoint(@data) {
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

print "====== calling gnuplot =========\n";

$gnuplot = "/usr/bin/gnuplot";

(my $pathbase = $infile)   =~ s{\.[^.]+$}{}; # removes extension
(my $basename = $pathbase) =~ s{.*/}{};      # removes path

printf("basename: >>%s<<, pathbase >>%s<<, infile: >>%s<<\n",   $basename , $pathbase , $infile);

$tempfile_dir = $pathbase;
my $i = 0;

while (-d $tempfile_dir) {
	$i++;
	$tempfile_dir = sprintf("%s_%d", $pathbase, $i);
}

mkdir $tempfile_dir;

$tempfile_prefix = sprintf("%s/%s", $tempfile_dir, $basename);
printf("dir: %s ; prefix: %s\n", $tempfile_dir , $tempfile_prefix);

# $tempfile_body = $tempfile_prefix . $time_suffix;
$tempfile_body = $tempfile_prefix;


$templog  = $tempfile_body . '.log';
$tempcmd  = $tempfile_body . '.cmd';

# for combined data output .. still to do
$temppng_all  = $tempfile_body . '_all.png';		# rectangle plot of all sats
# $temppng_sky  = $tempfile_body . '_sky.png';		# polar skyplot color coded
# $tempdata_all = $tempfile_body . '_all.data';

# header for all SV on top of each other
$command_all = <<ENDOFCMDALL;
set term png
set output "$temppng_all"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
set multiplot
ENDOFCMDALL

# animated GIF with all SV in sequence
$tempgif_anim  = $tempfile_body . '_anim.gif';

$command_anim = <<ENDOFCMDANIM;
set term  gif animate opt delay 100
set output "$tempgif_anim"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
ENDOFCMDANIM



foreach $SV (1 .. @svs) {
	if (! ($hits = $svs[$SV])) { next ; }


	$temppng_sv  = sprintf ("%s_%03d.png", $tempfile_body , $SV);
	$tempdata_sv = sprintf ("%s_%03d.data", $tempfile_body , $SV);

	printf ("writing data for SV# %d with %d data points ... ", $SV, $hits);

	open (DATAFILE, ">".$tempdata_sv) || error ("could not create temp data file $tempdata_sv");

	foreach $i (0..$#{$sv_ele[$SV]}) {
		printf DATAFILE ("%s %s\n", $sv_snr[$SV][$i], $sv_ele[$SV][$i] );

	}

	close DATAFILE || error ("could not close temp data file $tempdata_sv");

	printf ("creating chart for SV# %d....\n", $SV);

	# create single plot for each SV	 
	$command= <<ENDOFCOMMAND;
set term png
set output "$temppng_sv"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
plot "$tempdata_sv" using 2:1 with points lt $SV

ENDOFCOMMAND

	gnuplotcmd($command);


	# add entry for multi SV plotplot "
	$command_all .= "plot \"$tempdata_sv\" using 2:1 with points lt $SV\n";

	# add entry for multi SV animated gif
	$command_anim .= "plot \"$tempdata_sv\" using 2:1 with points lt $SV\n";
	
}

print "rendering combined plot\n";
# render the combined plot
gnuplotcmd($command_all);

print "rendering animated gif plot\n";
# render animated gif
gnuplotcmd($command_anim);

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
	close CMDLOG ; 

	open GNUPLOT, "| $gnuplot > $templog 2>&1" || error ("cannot open gnuplot")   ;
	print GNUPLOT $cmd    || error ("cannot send data to gnuplot") ;
	close GNUPLOT ;   

}
