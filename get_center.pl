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
   if( /^\$G([NPLBAQ])(GGA),(.*)(\*..)$/  ) { # process only GGA lines
      my @fields = split (',' , $3);
      print "\n";
      print scalar @fields ;

      # parse time like hhmmss.ssi 194832.000, millisecs may vary
      my($hh, $mm, $ss) = (  $fields[0] =~ /^(\d{2})(\d{2})(\d{2}\.?\d{,4})$/ );
      printf("time string: %s -> hr: %d, min: %d, sec: %s | ", $fields[0], $hh, $mm, $ss);

      # parse lat / lon ddmm.mmmmmmmm
      my($lat_deg, $lat_min) = ( $fields[1] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lat: %s -> deg:%d, min: %s | ", $fields[1], $lat_deg, $lat_min );
      # TBD: process South and West - no test data
      my($lon_deg, $lon_min) = ( $fields[3] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lon: %s -> deg:%d, min: %s | ", $fields[1], $lon_deg, $lon_min );



      print "\n";
   } else { # other line than $G*GGA
	print '.';
   }
	
}

print "\n";



