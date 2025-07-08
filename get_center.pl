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
# ====================
# config

# hash has best testing performance
my %qselect = (
	# 0 => 'invalid',
	# 1 => 'single',
	# 2 => 'diff',
	# 3 => 'PPS',
	4 => 'RTK fix',
	# 5 => 'RTK float',
	# 6 => 'DR',
	# 7 => 'manual',
	# 8 => 'simulator',
      );


# ====================
# read from file in @ARGV
while (<>) {
   chomp ; chop ;
   if( /^\$G([NPLBAQ])(GGA),(.*)(\*..)$/  ) { # process only GGA lines
      my @fields = split (',' , $3);
      print "\n$_\n";
      print scalar @fields ;
      # unicore ref manual, testest with UM98X and quectel LC29H
      # parse time like hhmmss.ssi 194832.000, millisecs may vary
      my($hh, $mm, $ss) = (  $fields[0] =~ /^(\d{2})(\d{2})(\d{2}\.?\d{,4})$/ );
      printf("time string: %s -> hr: %d, min: %d, sec: %s | ", $fields[0], $hh, $mm, $ss);

      # parse lat / lon ddmm.mmmmmmmm
      my($lat_deg, $lat_min) = ( $fields[1] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lat: %s -> deg:%d, min: %s | ", $fields[1], $lat_deg, $lat_min );
      # TBD: process South and West - no test data
      my($lon_deg, $lon_min) = ( $fields[3] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lon: %s -> deg:%d, min: %s | ", $fields[1], $lon_deg, $lon_min );

      my $qual = $fields[5];
      next unless defined $qselect{$qual};
      my $sats = $fields[6];
      my $hdop = $fields[7];
      my $alt  = $fields[8];
      my $age  = $fields[13];
      printf("q: %1s sv: %d hdop: %s alt: %s age: %s | ", 
             $qual,  $sats, $hdop,   $alt , $age);
            

      print "\n";
   } else { # other line than $G*GGA
	print '.';
   }
	
}

print "\n";



