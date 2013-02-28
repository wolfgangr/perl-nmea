#!/usr/bin/perl


# prepare/aggregate data for reverse hologram computaion
#

$inbase = $ARGV[0] or die ("usage: $0 inputpath/base");

$infilefilter = $inbase  . "_[0-9][0-9][0-9].data";
@infiles = `ls -1 $infilefilter` or die ("no input file match");


# derive unique output file name from inbase
$outfile = $inbase . "_holo.dat" ;
my $i = 0;
while (-e $outfile) {
	$i++;
	$outfile = sprintf("%s_%d_holo.dat", $inbase, $i);
}

open (OUTFILE , ">".$outfile) || die ("cannot open outfile $outfile");

print ("writing output to file $outfile \n");

my $lines_tot = 0;
my $lines_tot_out= 0;

foreach $infile (@infiles) {
	chomp $infile;
	print "$infile ...  ";

	open (INFILE, $infile) || die ("cannot read from file $infile");
	my $lines_in = 0;
	my $lines_skipped =0;
	my $lines_agg = 0; 
	my $lines_out = 0;

	my $ele_prev =  undef;
	my$azi_prev = undef;

	while (<INFILE>) {
		# print $_;
		$lines_in ++;	
		$lines_tot_in ++;
		@inlist = split ; #  ($_);
		# print (join ("|", @inlist ), "\n");
		unless ($#inlist == 5) { die ("format of $infile does not match"); }
		# die ("cutting edge");
		my ($t, $ele_int, $azi_int, $snr, $ele_frac, $azi_frac) = @inlist;
		
		# skip if no valid snr, elev. or azim. value
		unless ($snr > 1) { $lines_skipped ++ ; next; }
		unless ($ele_int >= 1) { $lines_skipped ++ ; next; }
		unless ($azi_int >= 1) { $lines_skipped ++ ; next; }

		# initialize if necessary
		unless (defined ($ele_prev) and defined ($azi_prev) ) {
			$ele_prev = $ele_int;
			$azi_prev = $azi_int;
			%snr_list = {};
		}

		unless ($ele_prev == $ele_int and $azi_prev == $azi_int) {
			# writing aggregated data
			foreach my $snr_ (sort keys %snr_list) {
				my $n = $snr_list{$snr_}->[0] ;
				unless ($n) { next ; }
				
				# bookkeeping
				$lines_out ++;
				$lines_tot_out++;				
				
				printf OUTFILE ("%f %f %d %d\n", 
					$snr_list{$snr_}->[1] / $n ,
					$snr_list{$snr_}->[2] / $n ,
					$snr_, $n );
				
			} 


			# force init sequence as in start
			$ele_prev = $ele_int;
			$azi_prev = $azi_int;		
			%snr_list = {};
			# redo; # repeat interation w/o calling "while (<INFILE>) "
		}



		# if ($ele_prev == $ele_int and $azi_prev == $azi_int) {
		{
			# continue collecting data
			$lines_agg ++;
			unless (exists $snr_list{$snr}) {
				# first occurance of this $snr in current azi/ele pairing
				$snr_list{$snr} = (1, $ele_frac, $azi_frac);
			} else {
				# repeated occurence, collect statistics
				$snr_list{$snr}->[0] ++;
				$snr_list{$snr}->[1] += $ele_frac;
				$snr_list{$snr}->[2] += $azi_frac;
			}

		} # else {





	}
	# die ("cutting edge");
	printf ("\n\t%d lines in, %d skipped, %d aggregated, %d out, total %d in, %d out \n", 
		$lines_in, $lines_skipped, $lines_agg, $lines_out, 
		$lines_tot_in, $lines_tot_out);
  		
}

die ("======= THE END ===========\n");
