#!/usr/bin/perl

############################################################
# llbs: low-level brainsuck
#
# by eXerigumo Clanjor (哆啦比猫/兰威举), 2012.
# Licensed under GPLv2. ABSOLUTELY NO WARRANTY!
############################################################


my $func = 0;
my $line_no = 0;

print ">>>+[\n";

while (<STDIN>) {
	$line_no++;

	s/#.*$//g;						# kill comments
	s/[\t\n\r]+/ /g;				# kill tabs and returns
	s/ +/ /g;						# uniq multiple spaces
	s/^ +//g;						# kill line-start spaces
	s/ +$//g;						# kill line-end   spaces

	if (!$_) { next; }				# skip blank lines

	# get operator and parameters
	my ($op, undef, undef, $_) = /^(([a-zA-Z]+)|@)( (.*))?$/;

	s/ +//g;						# kill spaces in parameters
	my @p = split ",";				# all the parameters are here

	print STDERR "::: $op : @p\n";	###### DEBUG ######

	for ($op) {
		/^\@$/ and do {
			print "\t>->]<+[\n\n" if $func++;
			print "\t<[->-]>[-<<\n";
			last;
		};

		/^push$/ and do {
			if (@p == 0) {
				print "\t>\n";
			}
			elsif (@p == 1) {
				$_ = $p[0];
				if (/^[0-9]+$/) {
					print "\t>" . "+"x$_ . "\n";
				}
				elsif (($_) = /^\[([0-9]+)\]$/) {
					print "\t" . "<"x$_ . "[-" . ">"x($_+1) .
						"+>+" . "<"x($_+2) . "]" . ">"x($_+2) .
						"[-" . "<"x($_+2) . "+" . ">"x($_+2) . "]<\n";
				}
				else { die "[$line_no] invalid parameter: @p\n"; }
			}
			else { die "[$line_no] invalid parameter: @p\n"; }
			last;
		};

		/^pop$/ and do {
			if (@p == 0) {
				print "\t[-]<\n";
			}
			elsif (@p == 1) {
				$_ = $p[0];
				if (($_) = /^\[([0-9]+)\]$/) {
					print "\t[-" . "<"x($_+1) . "+" . ">"x($_+1) . "]<\n";
				}
				else { die "[$line_no] invalid parameter: @p\n"; }
			}
			else { die "[$line_no] invalid parameter: @p\n"; }
			last;
		};

		/^if$/ and do {
			last;
		};

		/^go$/ and do {
			if (@p == 0) {
				die "[$line_no] parameter expected\n";
			}
			elsif (@p == 1) {
				$_ = $p[0];
				if (/^[0-9]+$/) {
					print "\t>" . "+"x$_ . "\n";
				}
				else { die "[$line_no] invalid parameter: @p\n"; }
			}
			elsif (@p == 2) {
				if ($p[0] =~ /^[0-9]+$/ && $p[1] =~ /^[0-9]+$/) {
					print "\t>" . "+"x$p[1] . ">" . "+"x$p[0] . "\n";
				}
				else { die "[$line_no] invalid parameter: @p\n"; }
			}
			else { die "[$line_no] invalid parameter: @p\n"; }
			last;
		};

		/^write$/ and do {
			print "\t";
			print ">" . "+" x $p[0] if $p[0] =~ /[0-9]+/;
			print ".[-]<\n";
			last;
		};

		/^add$/ and do {
			if (@p == 0) {
				print "\t[-<+>]<\n";
			}
			elsif (@p == 1) {
				$_ = $p[0];
				if (/^[0-9]+$/) {
					print "\t" . "+"x$_ . "\n";
				}
				else { die "[$line_no] invalid parameter: @p\n"; }
			}
			else { die "[$line_no] invalid parameter: @p\n"; }
			last;
		};

		/^exit$/ and do {
			print "\t>>>+<<<\n";
			last;
		};

		die "[$line_no] unknown operator: $op\n";
	}
}

print "\t>->]<+[\n-" . "]" x $func;
print "\n+>>[-<<->>]<<]\n";

