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
	$options{table} | $options{array} |
	$options{systems} | $options{sigids} | $options{freqs}
);

print STDERR Dumper(\%options);
# exit; # ===========================================

if ($options{help}) {
        usage ();
}

die("DEBUG option processing"); # ===========================================~~~~~~~~~~--------------

# ==== import GNSS systems specs ===========================

require "./GNSS_def.pl";
our %systems;
our @sigids;
our @sig_freqs;

our %SIG_TABLE; 
our @SIG_TABLE_ary;

# ======================================================

$Data::Dumper::Sortkeys = 1;
# print Data::Dumper->Dump([\@svs_sorted], [qw(\@svs_sorted)] );


# print Dumper (\%SIG_TABLE);
# print Dumper (\@SIG_TABLE_ary);
# exit;
# print Dumper (\%systems);
# print Dumper (\@sigids);
# print Dumper (\@sig_freqs);


# ==== SUBS  =======

sub usage {
        print  <<EOU;

Human readable printing of GNSS data definition
all output goes to STDOUT

Usage:

  -h|--help
	show this message

  -c|--config <path to GNSS system config file> 
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

