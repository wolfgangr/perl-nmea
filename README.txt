If you torture your Data long enough, it finally will confess ;-)

There are some nice tools and papers around that use carrier noise ratio of GPS receivers to assess antenna performance.

Takura Takasu, author of rtklib:
http://gpspp.sakura.ne.jp/paper2005/isgps2008_paper_ttaka.pdf

Josef Gerstenberg in a German GPS forum
http://www.kowoma.de/gpsforum/viewtopic.php?p=15374#p15374

Experimental Analysis of a Choke Ring Antenna (J.S. Ardaens)
http://www.weblab.dlr.de/rbrt/pdf/TN_0505.pdf

The focus of the author of the script at hand is on low-cost-high-precision GPS, mainly for the purpose of precision farming.
Consumer grade receivers with the capability of raw data output are used to feed rtklib for a precise GPS solution. However, the antenna is reported to be critical component. The issue of multipath-suppression may be crucial for a precise solution. Mounted on agricultural machinery consisting of large metal parts, there is large (and constantly changing) multipath potential to be expected.

Ardaens / Gerstenberg look for special structures in the CNo over Elevation plot to infer on multipath suppression capabilities of the antenna configuration. Gerstenberg calculates the standard deviation of CNo as multipath indicator. His plots show distinct patterns of periodicy, which is to be expected, since multipath is an interfernce based process.

The idea is to go further down this track and refine the statisic analysis of CNR patterns.

The scripts rely on NMA-Code as input data. This is widely available in the realm of consumer grade low-cost receivers, is highly standardized and contains a lot of useful information. No additional setup or data conversion tool is necessary.

In particular, it is the $GPGSV record of the standard NMEA data stream, which contains satelites in view, elevation, azimuth and SNR figures. 

# http://www.nmea.de/nmea0183datensaetze.html#gsv
# 1) total number of messages
# 2) message number
# 3) satellites in view
# 4) satellite number
# 5) elevation in degrees
# 6) azimuth in degrees to true
# 7) SNR in dB
# more satellite infos like 4)-7)


The script is written in PERL which is a powerful tool for extraction of text based data.
Plotting is deferrred to gnuplot, which is full of abundant power as well. After initial try with some interface library, it was decided to implement straight forward integration of gnuplot into perl with data files and command pipes. This keeps all power, flexibility and transparency of gnuplot open, without an intermediary "obscurity layer".

February 21 2013
Wolfgang Rosner
wrosner@tirnet.de


