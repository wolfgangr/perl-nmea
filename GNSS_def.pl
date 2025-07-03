# GNSS Systems, Sigs, Freq
# Table 7-1 Satellite Systems and Abbreviations

use Readonly;

Readonly our @systems_tags => qw(Multi GPS GLONASS Galileo BDS QZSS IRNSS);
Readonly our @systems_ltr  => qw(N      P   L       A      B   Q    I);
Readonly our %systems => map { $systems_ltr[$_] => {
    letter => $systems_ltr[$_],
    tag    => $systems_tags[$_],
    idx    => $_
  }    } (0 .. $#systems_ltr);

# Table 7-34 GNSS ID
Readonly our @sigids => ( [],
        [ qw(all L1_CA L1_PY L1_M L2_PY L2C-M L2C-L L5-I L5-Q) ],
        [ qw(all G1_CA G1_P       G2_CA G2_P) ],
        [ qw(all E5a E5b E5ab E6A E6BC L1A L1BC ) ],
        [ qw(all B1I B1Q B1C B1A B2a B2b B2ab B3I B3Q B3A B2I B2Q ) ],
        [ qw(all L1CA L1CD L1CP LIS L2CM L2CL L5I L5Q L6D L6E ) ],
        [ qw(all L5_SPS S_SPS L5_RS S_RS L1_SPS ) ]
  );

# https://de.wikipedia.org/wiki/Globales_Navigationssatellitensystem#/media/Datei:Gnss_bandwidth.svg
# https://gssc.esa.int/navipedia/images/c/cf/GNSS_All_Signals.png
# ... cum grano salis ...
# TODO: update and cross-check
Readonly our @sig_freqs => ( [],
        [ 0, (1575.42) x 3, (1227.6) x 3, (1176.45) x 2 ],
        [ 0, (1602) x 2, (1246) x 2],
        [ 0, (1191.8) x 3, (1278.75) x 2, (1575.42) x 2 ],
        [ 0, (1575.42) x 4, (1191.8) x 3, (1268.52) x 3 , (1207.14) x 2 ],
        [ 0, (1575.42) x 4, (1227.6) x 2, (1176.45) x 2 , (1278.75) x 2 ],
        [ 0, (1176.45) x 4 , 1575.42 ]
);

# mainly for crosschecking
our %SIG_TABLE;
our @SIG_TABLE_ary;

for my $sys_idx (0 .. $#systems_ltr) {
  my %sys_plan;
  my @sys_plan_ary =();
  my $sys_tag = $systems_tags[$sys_idx];

  for my $sig_idx (0 .. $#{$sigids[$sys_idx]} ) {
    # print $sys_idx, '-', $sig_idx, "\n";
    my $sig_tag = $sigids[$sys_idx][$sig_idx];
    my $sig_frq = $sig_freqs[$sys_idx][$sig_idx];
    $sys_plan{$sig_tag} = {
      sys_idx => $sys_idx,
      sys_tag => $sys_tag,
      sig_idx => $sig_idx,
      sig_tag => $sig_tag,
      frequ   => $sig_frq
    } ;
    push @sys_plan_ary, $sys_plan{$sig_tag};
  }
  $SIG_TABLE{$sys_tag} = \%sys_plan;
  push @SIG_TABLE_ary, \@sys_plan_ary;
}

# print Dumper (\%SIG_TABLE);
# print Dumper (\@SIG_TABLE_ary);
# exit;
# print Dumper (\%systems);
# print Dumper (\@sigids);
# print Dumper (\@sig_freqs);
# exit;
1;
