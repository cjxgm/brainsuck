#!/usr/bin/perl

############################################################
# brainsuck: the compiler frontend
#
# by eXerigumo Clanjor (哆啦比猫/兰威举), 2012.
# Licensed under GPLv2. ABSOLUTELY NO WARRANTY!
############################################################

$_ = `bs | llbs`;
s/[\n\r\t ]+//g;
s/\+-//g;
s/-\+//g;
s/<>//g;
s/><//g;
print;
print "\n";

