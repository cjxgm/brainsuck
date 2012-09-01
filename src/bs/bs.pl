#!/usr/bin/perl

############################################################
# bs: the brainsuck compiler
#
# by eXerigumo Clanjor (哆啦比猫/兰威举), 2012.
# Licensed under GPLv2. ABSOLUTELY NO WARRANTY!
############################################################

use strict;


############################################################
#
# variables
#

# compiler
my $source;

# parser
my %tk  = (name => undef, type => undef);
my %tk2 = %tk;
my $retreated = undef;
my @keywords = qw(if else while break continue return exit);
my @dsymbols = qw(++ -- += -= == != >= <= && ||);

# code generator
my @funcs;
my $fcurrent;

############################################################
#
# main
#

&compile;


############################################################
#
# compiler
#

sub compile
{
	while (<>) { $source .= $_ }
	&advance;
	&bs_program;
	&gen_code;
}

sub find_func
{
	my $name = shift;
	my $id   = 0;

	foreach (@funcs) {
		return $id if $$_{name} eq $name;
		$id++;
	}

	-1;
}


############################################################
#
# parser
#

sub advance
{
	if ($retreated) {
		(%tk, %tk2) = (%tk2, %tk);
		$retreated  = undef;
		return;
	}

	%tk2 = %tk;

	# skip blanks and comments
	while ($source =~ s/^([ \t\n\r]+|#.*)//g) {}

	for ($source) {
		# identifier or keyword
		s/^([a-zA-Z_][a-zA-Z0-9_.]*)//g and do {
			$source = $_;
			$tk{name} = $1;
			$tk{type} = ($1 ~~ @keywords) ? 'KEY' : 'ID';
			last;
		};

		# string
		s/^"([^"\n\r]*)"//g and do {
			$source = $_;
			$tk{name} = $1;
			$tk{type} = 'STR';
			last;
		};

		# byte
		s/^([0-9]+)//g and do {
			die "$1 is out of range.\n" unless $1 < 256;
			$source = $_;
			$tk{name} = $1;
			$tk{type} = 'BYTE';
			last;
		};

		# byte (written in char)
		s/^'(.)'//g and do {
			$source = $_;
			$tk{name} = ord $1;
			$tk{type} = 'BYTE';
			last;
		};

		# double symbol
		/^(..)/ and $1 ~~ @dsymbols and do {
			$tk{name} = $1;
			$tk{type} = 'SYM';
			s/^..//g;
			$source = $_;
			last;
		};

		# single symbol
		s/^([+\-><=,;(){}!\@])//g and do {
			$source = $_;
			$tk{name} = $1;
			$tk{type} = 'SYM';
			last;
		};

		# nothing matched
		die "invalid character: " . chr(ord $source) .
			"(" . ord($source) . ")\n" if $source;

		# end of file
		$tk{type} = undef;
	}

	###### DEBUG ######
	print STDERR ": $tk{type}\t$tk{name}\n";
}

sub retreat
{
	die "unable to retreat.\n" if $retreated;
	(%tk, %tk2) = (%tk2, %tk);
	$retreated  = 1;
}

sub match
{
	return unless $tk{type} eq shift;
	if ($_[0]) { return unless $tk{name} eq $_[0] }
	1;
}

sub match_or_die
{
	match $_[0], $_[1] or die "$_[0] " . "'"x($_[1] ne "") . "$_[1]" .
								"' "x($_[1] ne "") . "expected" .
								" "x($_[2] ne "") . "$_[2].\n";
}

sub bs_program
{
	while (!match()) { push @funcs, &bs_func }
}

sub bs_func
{
	match_or_die 'ID', '', "for function declaration";
	find_func($tk{name}) + 1 and die "function '$tk{name}' redefined.\n";

	my %p = (type => 'FUNC', name => $tk{name}, params => []);
	&advance;

	match_or_die 'SYM', '(', "for function declaration";
	&advance;

	$p{params} = &bs_param_decl_list unless match 'SYM', ')';
	match_or_die 'SYM', ')', "for function declaration";
	&advance;

	match_or_die 'SYM', '{', "for function declaration";
	&advance;

	my @t;
	while (my $s = &bs_stmt) { push @t, $s }
	$p{body} = \@t;

	match_or_die 'SYM', '}', "for function declaration";
	&advance;

	return \%p;
}

sub bs_param_decl_list
{
	my @p;

	while (1) {
		match_or_die 'ID', '', "for parameter declaration";
		push @p, $tk{name};
		&advance;

		match 'SYM', ',' or last;
		&advance;
	}
	
	return \@p;
}

sub bs_stmt
{
	my %p;

	while (match('SYM', ';')) { &advance }

	match('KEY', 'break') and do {
		$p{type} = 'BREAK';
		&advance;

		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};

	match('KEY', 'continue') and do {
		$p{type} = 'CONTINUE';
		&advance;

		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};

	match('KEY', 'exit') and do {
		$p{type} = 'EXIT';
		&advance;

		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};

	match('STR') and do {
		$p{type} = 'STRING';
		$p{name} = $tk{name};
		&advance;

		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};

	undef;
}


############################################################
#
# code generator
#

sub gen_code
{
	my $end = $#funcs;

	foreach my $id (0 .. $end) {
		$fcurrent = $id;
		do_gen_code($funcs[$id]);
	}

	foreach my $id (0 .. $end) { print ${$funcs[$id]}{code} }
}

sub do_gen_code
{
	my %p = %{$_[0]};

	for ($p{type}) {
		/^FUNC$/ and do {
			print STDERR "> $p{type}\t$p{name}\t@{$p{params}}\n";
			foreach (@{$p{body}}) { do_gen_code($_) }
			last;
		};

		/^BREAK$/ and do {
			print STDERR "> $p{type}\n";
			last;
		};

		/^CONTINUE$/ and do {
			print STDERR "> $p{type}\n";
			last;
		};

		/^EXIT$/ and do {
			gen("\texit\n");
			last;
		};

		/^STRING$/ and do {
			$_ = $p{name};
			while (s/^(.)//g) { gen("\twrite\t" . ord($1) . "\n") }
			last;
		};
	}
}

sub gen
{
	${$funcs[$fcurrent]}{code} .= shift;
}

