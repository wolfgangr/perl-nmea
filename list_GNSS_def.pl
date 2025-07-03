#!/usr/bin/perl

# debug / info GNSS system definitions
# (C) by Wolfgang Rosner
# wrosner@tirnet.de
# immature worl in progress
# not for real live use
# provided "as is", don`t pay me but don`t sue me...



use warnings;
use strict;

use Getopt::Long;
use Data::Dumper ;

# ==== option processing ===================

my %options =();
# $options{table}='default';
GetOptions (  \%options, "config|c=s@",  "help|h|?",
	"table|t", 	"array|a",
	"systems|y",	"sigids|i",	"freqs|f"

                ) or usage ();

$options{table}='default' unless ( 
	# (  ! scalar %options) || 
	(  scalar %options) && 
	$options{table} || $options{array} ||
	$options{systems} || $options{sigids} || $options{freqs}
);

print STDERR Dumper(\%options);
# exit; # ===========================================

if ($options{help}) {
        usage ();
}

if ($options{config}) {
        die "--config not yet implemented";
}


# die("DEBUG option processing"); #

# ==== import GNSS systems specs ===========================
# my $config = $options{config} // "./GNSS_def.pl";
# my $config =  "./GNSS_def.pl";
# $config = $options{config} if defined $config = $options{config} ;
# eval `cat  $config`;
# require  $config;
require "./GNSS_def.pl";
# eval $config;
our %systems;
our @sigids;
our @sig_freqs;

our %SIG_TABLE; 
our @SIG_TABLE_ary;

# ======================================================

$Data::Dumper::Sortkeys = 1;
# print Data::Dumper->Dump([\@svs_sorted], [qw(\@svs_sorted)] );

# print Dumper (\%SIG_TABLE);
if ($options{table}) {
	print Data::Dumper->Dump([\%SIG_TABLE], [qw(\%SIG_TABLE)] )
}

# print Dumper (\@SIG_TABLE_ary);
if ($options{array}) {
        print Data::Dumper->Dump([\@SIG_TABLE_ary], [qw(\@SIG_TABLE_ary)] )
}

# print Dumper (\systems);
if ($options{systems}) {
        print Data::Dumper->Dump([\%systems], [qw(\%systems)] )
}

# print Dumper (\@sigids);
if ($options{sigids}) {
        print Data::Dumper->Dump([\@sigids], [qw(\@sigids)] )
}

# print Dumper (\@sig_freqs);
if ($options{freqs}) {
        print Data::Dumper->Dump([\@sig_freqs], [qw(\@sig_freqs)] )
}

print STDERR "DONE\n";
exit;
# ==== SUBS  =======

sub usage {
        print  <<EOU;

Human readable printing of GNSS data definition
all output goes to STDOUT

Usage:

  -h|--help
	show this message

  -c|--config <path to GNSS system config file> 
	### TBD
	Default: ./GNSS_def.pl

output options (may be combined)
  -t|--table
	print Sys X Sig hash table [default]

  -a|--array
	print Sys X Sig array

  -y|--systems
	print raw GNSS %systems hash table

  -i|--sigids
	print raw GNSS signal-ID array

  -f|-freqs
	print raw GNSS signal-frequency array

EOU
        exit (0);
} # - end of sub usage -

