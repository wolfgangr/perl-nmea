#!/usr/bin/perl

# read NMEA data,
# quick hack to find base station antenna coordinate
# record som hrs of RTK fix supported by other caster
# grep GGA to speed operation
# load that file with this script
# to get some statistics

use warnings;
use strict;

use Data::Dumper ;

# read from file in @ARGV
while (<>) {
   chomp ; chop ;
   if( /^\$G([NPLBAQ])(GGA),(.*)(\*..)$/  ) {
      my @fields = split (',' , $3);
      print "\n";
      print scalar @fields ;
      my($hh, $mm, $ss) = (  $fields[0] =~ /^(\d{2})(\d{2})(\d{2}\.?\d{,4})$/ );
      printf("time string: %s -> hr: %d, min: %d, sec: %s", $fields[0], $hh, $mm, $ss);
      print "\n";
   } else {
	print '.';
   }
	
}

print "\n";



