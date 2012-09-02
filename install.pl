#!/usr/bin/perl

############################################################
# install: the installer
#
# by eXerigumo Clanjor (哆啦比猫/兰威举), 2012.
# Licensed under GPLv2. ABSOLUTELY NO WARRANTY!
############################################################

# copy the wrapper
open FIN,  "<src/brainsuck.pl" or die $!;
open FOUT, ">/usr/local/bin/brainsuck" or die $!;
while (<FIN>) { print FOUT }
close FIN;
close FOUT;
chmod 0755, "/usr/local/bin/brainsuck" or die $!;

# copy llbs, filtering out the debugging info
open FIN,  "<src/llbs/llbs.pl" or die $!;
open FOUT, ">/usr/local/bin/llbs" or die $!;
while (<FIN>) {
	s/^.*print STDERR.*[\n\r]*//g;
	print FOUT;
}
close FIN;
close FOUT;
chmod 0755, "/usr/local/bin/llbs" or die $!;

# copy bs, filtering out the debugging info
open FIN,  "<src/bs/bs.pl" or die $!;
open FOUT, ">/usr/local/bin/bs" or die $!;
while (<FIN>) {
	s/^.*print STDERR.*[\n\r]*//g;
	print FOUT;
}
close FIN;
close FOUT;
chmod 0755, "/usr/local/bin/bs" or die $!;

