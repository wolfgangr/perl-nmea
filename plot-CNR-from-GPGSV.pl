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
# ./plot-CNR-from-GPGSV.pl < log-2013-02-16-23-16.nmea


# use DateTime;		# really heavy
# use DateTime::Tiny;   # cannot resolve backwards
use Time::Local 'timegm_nocheck' ;	# tiny but what I need
use Data::Dumper ;
# use Chart::Gnuplot;  ... no advantage to add any obscurity layer .. use "| gnuplot" instead

# in a data base, this might be tables
@data =();	# collection of pointers to all sv x time data
%times =(); 	# pointer to arrays of all data for each time
@svs =();	# count number of data for each sv

# @recent=(); # memorize current sv data until we have a valid time

# read from stdin

$infile = $ARGV[0] or die ("usage: $0 someinputfile.name");
open INFILE , $infile or die ("cannot read from input file named $infile");

while(<INFILE>) {
	# print $_;
	chomp ; chop ; #  looks like chomp removes NL but leaves CR 
	# ($qual, $data, $chskum) =~ /(\$GP\D{3})(.*)(,\*\d{2})/ ;

	# parse GSV lines
	if( /\$GP(\w{3}),(.*)(\*..)$/  ) { 
 		# /\$GP(GSV)(.*)(\*..)$/ ;
	
		### printf (">>%s<< >>%s<< >>%s<<\n", $1, $2, $3);	# $qual, $data, $chskum);

		@fields = split (',' , $2);

		if($1 eq 'RMC') {
			### print ("RMC-record: ");
			# print $fields[0]; 	# UTC hhmmss.ss

			# print " - ";
			# print $fields[8];	# Date, ddmmyy 
			# print (" | ");

                        my $hh = substr($fields[0], 0, 2);
                        my $mm = substr($fields[0], 2, 2);
                        my $ss = substr($fields[0], 4, 2);
			my $ms = ( ( "0" . substr($fields[0], 6) ) * 1000);
			

                        my $dd = substr($fields[8], 0, 2);
                        my $MM = substr($fields[8], 2, 2);
                        my $yy = substr($fields[8], 4, 2) + 2000 ;

			$timestamp = timegm_nocheck($ss,$mm,$hh,$dd,$MM-1,$yy);
			# check by reverse conversion
			### print scalar gmtime $timestamp;
			### print "\n";

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
				@current =()
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
		print $_;
		print "\n";
	}



}

close INFILE;

#================
# debuh print: show what we have now:
print "======================== read complete =======================\n";

# print Dumper([@data]);
# print "--------------------------------------\n";
# print Dumper([%times]);
# print "--------------------------------------\n";
# print Dumper([@svs]);
# print "--------------------------------------\n";

# hey, we can make animated gif, so we can display multiple satellites?
# create 
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

# hmmm whatever we do we need x any y in matching arrays
# we like to keep them in higher level arrays by satelite number...

# @sv_time = []  x @svs ;


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


# so - what do we like to produce?
# cmp master takasu: http://gpspp.sakura.ne.jp/anteva/anteva.htm
# for each SV detailed analysis
# ANOVA ... this vs other sats ... this elve vs smoothed curve
# all sats simplified/aggregated together
# same in animated gif???
# skyplot cmp 
#	http://gpspp.sakura.ne.jp/anteva/antmpc.htm
#	http://gpspp.sakura.ne.jp/anteva/antsnr.htm
# can we produce 3D polar / cylindric / color encoded?
# alle Sats elev over time


print "====== calling gnuplot =========\n";

$gnuplot = "/usr/bin/gnuplot";

# (my $basename = $infile) =~ s/\.[^.]+$//;

# $name =~ s{.*/}{};      # removes path  
(my $pathbase = $infile)   =~ s{\.[^.]+$}{}; # removes extension
(my $basename = $pathbase) =~ s{.*/}{};      # removes path

printf("basename: >>%s<<, pathbase >>%s<<, infile: >>%s<<\n",   $basename , $pathbase , $infile);
# exit;

$tempfile_dir = $pathbase;
my $i = 0;

while (-d $tempfile_dir) {
	$i++;
	$tempfile_dir = sprintf("%s_%d", $pathbase, $i);
}

mkdir $tempfile_dir;

$tempfile_prefix = sprintf("%s/%s-", $tempfile_dir, $basename);

printf("dir: %s ; prefix: %s\n", $tempfile_dir , $tempfile_prefix);
#=============~~~~~~~~~~~~~~~~~~~~~~~~~---------------------------

exit;

$tempfile_prefix="./fig/test-";

$time_suffix = `date +%F-%T`;
chomp $time_suffix;

$tempfile_body = $tempfile_prefix . $time_suffix;
$temppng  = $tempfile_body . '.png';
$tempdata = $tempfile_body . '.data';
$templog  = $tempfile_body . '.log';



# SV no 12 for first trial
print "creating chart....\n";
#    my $chart = Chart::Gnuplot->new(
#        output => "fig/first.gif",
#	terminal => "gif",
#	xrange => [0, 90 ],
#	yrange => [0, 50 ]
#	 );


print "creating dataset....\n";
# my $dataSet = Chart::Gnuplot::DataSet->new(
#        xdata => @sv_ele[12],
#        ydata => @sv_snr[12]
#	);

# print Data::Dumper->Dump([ (@sv_ele[12] ) ]);
# print $#{$sv_ele[12]};
# print "\n";

# exit;

open (DATAFILE, ">".$tempdata) || error ("could not create temp data file $tempdata");

foreach $i (0..$#{$sv_ele[12]}) {
	printf DATAFILE ("%s %s\n", $sv_snr[12][$i], $sv_ele[12][$i] );

}

close DATAFILE || error ("could not close temp data file $tempdata");

print "calling plot  \n";
# $chart->plot2d($dataSet);


$command= <<ENDOFCOMMAND;
set term png
set output "$temppng"
set xrange [0:90]
set yrange [0:50]
set xlabel 'Elevation in deg'
set ylabel 'CNR in dbHz'
plot "$tempdata" using 2:1 with points

ENDOFCOMMAND

print $command;

open GNUPLOT, "| $gnuplot > $templog 2>&1" || error ("cannot open gnuplot")   ;
print GNUPLOT $command    || error ("cannot send data to gnuplot") ;
close GNUPLOT ;   


exit ;
###################################################################
sub error {
        my ($errmessg) = @_;
        die ("Error: " . $errmessg );
}


