#!/usr/bin/perl


# prepare/aggregate data for reverse hologram computaion
#

$inbase = $ARGV[0] or die ("usage: $0 inputpath/base");

$infilefilter = $inbase  . "_???.data";
@infiles = `ls -1 $infilefilter` or die ("no input file match");


# derive unique output file name from inbase
$outfile = $inbase . "_holo.dat" ;
my $i = 0;
while (-e $outfile) {
	$i++;
	$outfile = sprintf("%s_%d_holo.dat", $inbase, $i);
}

open (OUTFILE , ">".$outfile) || die ("cannot open outfile $outfile");

my $lines_tot = 0;
foreach $infile (@infiles) {
	chomp $infile;
	print "$infile ...  ";

	open (INFILE, $infile) || die ("cannot read from file $infile");
	my $lines_in = 0;
	while (<INFILE>) {
		# print $_;
		$lines_in ++;	
		$lines_tot ++;
		@inlist = split ; #  ($_);
		# print (join ("|", @inlist ), "\n");
		unless ($#inlist == 5) { die ("format of $infile does not match"); }
		# die ("cutting edge");
		my ($t, $ele_int, $azi_int, $snr, $ele_frac, $azi_frac) = @inlist;
	}
	# die ("cutting edge");
	printf ("%d lines, %d total \n", $lines_in, $lines_tot);
  		
}
