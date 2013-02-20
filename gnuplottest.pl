#!/usr/bin/perl

use Time::Local;
use Time::localtime;


$gnuplot = "/usr/bin/gnuplot";
# $tempfile_prefix="/usr/local/httpd/htdocs/html/tmp/sqlplot-";
#$tempfile_prefix="/srv/www/htdocs/tmp/sqlplot-";
$tempfile_prefix="./fig/test-";

$time_suffix = `date +%F-%T`;
chomp $time_suffix;

$tempfile_body = $tempfile_prefix . $time_suffix;
$temppng  = $tempfile_body . '.png';
$tempdata = $tempfile_body . '.data';
$templog  = $tempfile_body . '.log';



$command= <<ENDOFCOMMAND;
set term x11
test
set term png
set output "$temppng"
test
ENDOFCOMMAND


open GNUPLOT, "| $gnuplot -persist > $templog 2>&1" || error ("cannot open gnuplot")   ;
print GNUPLOT $command    || error ("cannot send data to gnuplot") ;
close GNUPLOT  ; #           || gnuploterror($command, $templog);


sub error {
	my ($errmessg) = @_;
	die ("Error: " . $errmessg );
}
