#!/usr/bin/perl

# read NMEA data,
# see http://www.nmea.de/nmea0183datensaetze.html#gsv
# extract Satellite view data
# and store it for modular postprocessing
# refactored 2025 for multi SYS, multi band NMEA 4.whatever
#
# Wolfgang Rosner
# wrosner@tirnet.de
# provided "as is", don`pay me but don`t sue me...
##
# spin-off of 
# ./plot-CNR-from-GPGSV.pl  log-2013-02-16-23-16.nmea


use warnings;
use strict;

use Time::Local 'timegm_nocheck' ;	# tiny but what I need
use Data::Dumper ;
# use Math::Interpolate qw(linear_interpolate robust_interpolate);
# use Math::Spline;

use Devel::Size qw(size total_size);
# use Readonly;

require "./GNSS_def.pl";
our %systems;
our @SIG_TABLE_ary;

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

# $Data::Dumper::Sortkeys = 1;
# print Data::Dumper->Dump([\@svs_sorted], [qw(\@svs_sorted)] );
# print Data::Dumper->Dump([\@svs_sig1],   [qw(\@svs_sig1)] );

# printf "\@svs_sorted has %d entries\n"  , scalar @svs_sorted;
# printf "\@svs_sig1   has %d entries\n"  , scalar @svs_sig1;

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
# goto COLLECT_STATS ;
#==============================================================================================
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

printf "\@svs_sorted has %d entries\n"  , scalar @svs_sorted;
printf "\@svs_sig1   has %d entries\n"  , scalar @svs_sig1;

# print Data::Dumper->Dump([\@svs_sorted], [qw(\@svs_sorted)] );
# print Data::Dumper->Dump([\@svs_sig1],   [qw(\@svs_sig1)] );


}

