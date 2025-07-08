#!/usr/bin/perl

# read NMEA data,
# quick hack to find base station antenna coordinate
# record som hrs of RTK fix supported by other caster
# grep GGA to speed operation
# load that file with this script
# to get some statistics

use warnings;
use strict;

# use Data::Dumper ;
use List::Util qw( min max );

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
# reference points 0.05 deg = 3 min ~  
my $lat_0 = 49.95;
my $lon_0 = 12.25;

# ====================
# read from file in @ARGV

# aggregator vars
my $line_cnt=0;

my $lat_cnt  = 0;
my $lat_sum  = 0;
my $lat_2sum = 0;
my $lat_min =  9999;
my $lat_max = -9999;

my $lon_cnt  = 0;
my $lon_sum  = 0;
my $lon_2sum = 0;
my $lon_min =  9999;
my $lon_max = -9999;


my $alt_cnt  = 0;
my $alt_sum  = 0;
my $alt_2sum = 0;
my $alt_min =  99999;
my $alt_max = -99999;

my $skip_cnt = 0; # lines not matching G*GGA
my $noq_cnt  = 0; # lines matching G*GGA but not quality pattern
my $err_cnt  = 0; # lines matching G*GGA but not being parsable

while (<>) {
   $line_cnt++;
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
      my($lat_deg, $lat_dmin) = ( $fields[1] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lat: %s -> deg:%d, min: %s | ", $fields[1], $lat_deg, $lat_dmin );
      # TBD: process South and West - no test data
      my($lon_deg, $lon_dmin) = ( $fields[3] =~ /^(\d{2,})(\d{2}\.\d+)$/ );
      printf("lon: %s -> deg:%d, min: %s | ", $fields[1], $lon_deg, $lon_dmin );

      my $qual = $fields[5];
      unless (defined $qselect{$qual}) {
         $noq_cnt++;
         next;
      }
      # my $sats = $fields[6];
      # my $hdop = $fields[7];
      my $alt  = $fields[8];
      # my $age  = $fields[13];
      # print "\n\t";
      # printf("q: %1s sv: %d hdop: %s alt: %s age: %s | ", 
      #       $qual,  $sats, $hdop,   $alt , $age);
            
      my $lat = $lat_deg + $lat_dmin/60;
      my $lon = $lon_deg + $lon_dmin/60;

      unless (defined $lat && defined $lon && defined $alt) {
         $err_cnt++;
         next;
      }
   
      # everything fine - collect aggregates
      $lat_cnt++;
      $lat_sum  += $lat;
      $lat_2sum += $lat * $lat;
      $lat_min = min ($lat_min, $lat);
      $lat_max = max ($lat_max, $lat);

      $lon_cnt++;
      $lon_sum  += $lon;
      $lon_2sum += $lon * $lon;
      $lon_min = min ($lon_min, $lon);
      $lon_max = max ($lon_max, $lon);

      $alt_cnt++;
      $alt_sum  += $alt;
      $alt_2sum += $alt * $alt;
      $alt_min = min ($alt_min, $alt);
      $alt_max = max ($alt_max, $alt);

      print "\n";
   } else { # other line than $G*GGA
        $skip_cnt++;
	print '.';
   }
	
}

print "\n\n------------------------------------------------------------\n";
printf ("total lines processed: %d\n", $line_cnt);
printf ("lat cnt: %d - lon cnt:   %d - alt cnt:       %D\n", $lat_cnt, $lon_cnt, $alt_cnt);
printf ("skipped: %d - qual miss: %d - format errors: %d\n", $skip_cnt, $noq_cnt, $err_cnt);

print "\n";
printf ("lat - cnt: %d  - sum: %f - sum of squares: %e \n", $lat_cnt, $lat_sum, $lat_2sum); 
printf ("\tmin: %.10f - max: %.10f \n", $lat_min, $lat_max);
printf ("lon - cnt: %d  - sum: %f -isum of squares: %e \n", $lon_cnt, $lon_sum, $lon_2sum);
printf ("\tmin: %.10f - max: %.10f \n", $lon_min, $lon_max);
printf ("alt - cnt: %d  - sum: %f - sum of squares: %e \n", $alt_cnt, $alt_sum, $alt_2sum);
printf ("\tmin: %.4f - max: %.4f \n", $alt_min, $alt_max);
