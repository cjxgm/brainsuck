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
my $fcurrent;
my @funcs;
my $var_offset = 0;
my @param_name;
my @var_name;
my @var_id;

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


############################################################
#
# parser
#

sub advance
{
	if ($retreated) {
		my %tkt = %tk;
		%tk     = %tk2;
		%tk2    = %tkt;
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
	my %tkt = %tk;
	%tk     = %tk2;
	%tk2    = %tkt;
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

	\%p;
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
	
	\@p;
}

sub bs_stmt
{
	my %p;

	while (match('SYM', ';')) { &advance }

	match('KEY', 'return') and do {
		$p{type} = 'RETURN';
		&advance;

		match 'SYM', ';' or $p{expr} = &bs_expr;
		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};

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

	match('KEY', 'if')    and return &bs_if;
	match('KEY', 'while') and return &bs_while;
	match('SYM', '@')     and return &bs_var_decls;

	match('STR') and do {
		$p{type} = 'STRING';
		$p{name} = $tk{name};
		&advance;

		match_or_die 'SYM', ';';
		&advance;

		return \%p;
	};


	match('ID') and do {
		&advance;

		(match('SYM', '++') or match('SYM', '--')) and do {
			$p{type} = $tk{name};
			&retreat;
			$p{name} = $tk{name};
			&advance;
			&advance;
			match_or_die 'SYM', ';';
			&advance;
			return \%p;
		};

		(match('SYM', '=') or match('SYM', '+=') or match('SYM', '-='))
		and do {
			&retreat;
			return &bs_assign;
		};

		&retreat;
		$p{type} = 'EXPR';
		$p{expr} = &bs_expr;
		match_or_die 'SYM', ';';
		&advance;
		return \%p;
	};

	undef;
}

sub bs_var_decls
{
	&advance;
	my %p = (type => 'VAR');
	my @p;

	push @p, &bs_var_decl;

	while (match('SYM', ',')) {
		&advance;
		push @p, &bs_var_decl;
	}

	match_or_die 'SYM', ';';
	&advance;

	$p{decls} = \@p;
	\%p;
}

sub bs_var_decl
{
	match_or_die 'ID', '', "for variable declaration";

	my %p = (name => $tk{name}, value => undef);
	&advance;

	match 'SYM', '=' and do {
		&advance;
		$p{value} = &bs_expr;
	};

	\%p;
}

sub bs_assign
{
	my %p;

	$p{name} = $tk{name};
	&advance;

	$p{type} = $tk{name};
	&advance;

	$p{expr} = &bs_expr;

	\%p;
}

sub bs_if
{
	my %p = (type => 'IF', else => undef);
	&advance;

	match_or_die 'SYM', '(', "for if statement's condition";
	&advance;

	$p{cond} = &bs_expr;

	match_or_die 'SYM', ')', "for if statement's condition";
	&advance;

	$p{then} = &bs_block;

	match 'KEY', 'else' and do {
		&advance;
		$p{else} = &bs_block;
	};

	\%p;
}

sub bs_while
{
	my %p = (type => 'WHILE');
	&advance;

	match_or_die 'SYM', '(', "for if statement's condition";
	&advance;

	$p{cond} = &bs_expr;

	match_or_die 'SYM', ')', "for if statement's condition";
	&advance;

	$p{body} = &bs_block;

	\%p;
}

sub bs_block
{
	match 'SYM', '{' and do {
		&advance;

		my %p = (type => 'BLOCK');
		my @p;
		while (my $p = &bs_stmt) { push @p, $p }
		$p{body} = \@p;

		match_or_die 'SYM', '}';
		&advance;

		return \%p;
	};

	&bs_stmt;
}

sub bs_expr
{
	&bs_factor;
}

sub bs_factor
{
	my %p;

	match 'BYTE' and do {
		$p{type} = 'BYTE';
		$p{name} = $tk{name};
		&advance;
		return \%p;
	};

	match 'ID' and do {
		&advance;
		match 'SYM', '(' and do {
			&retreat;
			return &bs_func_call;
		};
		&retreat;
		$p{type} = 'ID';
		$p{name} = $tk{name};
		&advance;
		return \%p;
	};

	match 'SYM', '!' and do {
		&advance;
		$p{type} = '!';
		$p{expr} = &bs_factor;
		return \%p;
	};

	match 'SYM', '(' and do {
		&advance;
		my $p = &bs_factor;
		match_or_die 'SYM', ')';
		&advance;
		return $p;
	};

	die "factor expected.\n";
}

sub bs_func_call
{
	my %p = (type => 'CALL', name => $tk{name}, params => undef);
	&advance;
	&advance;
	match 'SYM', ')' or $p{params} = &bs_param_list;
	match_or_die 'SYM', ')';
	&advance;
	return \%p;
}

sub bs_param_list
{
	my @p;
	while (1) {
		push @p, &bs_expr;
		match 'SYM', ',' or return \@p;
		&advance;
	}
}


############################################################
#
# code generator
#

sub gen_code
{
	my $main = find_func("main");
	$main+1 or die "function 'main' undefined.\n";

	my $ft = $funcs[0];
	$funcs[0] = $funcs[$main];
	$funcs[$main] = $ft;

	my $end = $#funcs;

	foreach my $id (0 .. $end) {
		$fcurrent = $id;
		do_gen_code($funcs[$id]);
		print STDERR ": @param_name\n";
	}

	print "# low-level brainsuck program\n";
	print "# generated by brainsuck compiler\n";
	print "# https://github.com/cjxgm/brainsuck\n\n";
	foreach (@funcs) { print "@\n$$_{code}\n" }
}

sub do_gen_code
{
	my %p = %{$_[0]};

	for ($p{type}) {
		/^FUNC$/ and do {
			print STDERR "> $p{type}\t$p{name}\t@{$p{params}}\n";
			@param_name = ();
			@var_name   = ();
			@var_id     = ();
			alloc_param("#");	# return value
			foreach (@{$p{params}}) { alloc_param($_) }
			foreach (@{$p{body}})   { do_gen_code($_) }
			foreach (@var_id)       { gen_pop("")     }
			$p{name} eq "main" and gen("exit");
			last;
		};

		/^VAR$/ and do {
			foreach my $d (@{$p{decls}}) {
				print STDERR "> $$d{name}\t$$d{value}\n";
				if ($$d{value}) { do_gen_code($$d{value}) }
				else { gen_push("") }
				alloc_var($$d{name});
			}
			last;
		};

		/^BYTE$/ and do {
			print STDERR "> $p{name}\n";
			gen_push($p{name});
			last;
		};

		/^ID$/ and do {
			print STDERR "> $p{name}\n";
			gen_push($p{name});
			last;
		};

		/^CALL$/ and do {
			print STDERR "> $p{name}\n";
			if ($p{name} eq "putc") {
				foreach (@{$p{params}}) {
					do_gen_code($_);
					gen("putc");
					gen_push("");
					$var_offset--;
				}
			}
			elsif ($p{name} eq "getc") {
				$p{params} and @{$p{params}}
						and die "invalid parameter for getc.\n";
				gen("getc");
				$var_offset++;
			}
			else {
				my $id = find_func($p{name});
				$id+1 or die "function '$p{name}' undefined.\n";

				gen_push("");
				foreach (@{$p{params}}) { do_gen_code($_) }

				my $ret = &alloc_func;
				gen("go\t\t$id, $ret");

				$fcurrent = $ret;
				foreach (@{$p{params}}) { gen_pop("") }
			}
			last;
		};

		/^WHILE$/ and do {
			my $while = &alloc_func;
			my $body  = &alloc_func;
			my $end   = &alloc_func;

			gen("go\t\t$while");
			$fcurrent = $while;

			do_gen_code($p{cond});
			gen("while\t$body, $end");
			$var_offset--;
			$fcurrent = $body;

			do_gen_code($p{body});
			gen("go\t\t$while");
			$fcurrent = $end;
			last;
		};

		/^BLOCK$/ and do {
			foreach (@{$p{body}}) { do_gen_code($_) }
			last;
		};

		/^EXPR$/ and do {
			do_gen_code($p{expr});
			gen_pop("");
			last;
		};

		/^=$/ and do {
			do_gen_code($p{expr});
			gen_pop($p{name});
			last;
		};

		/^\+=$/ and do {
			gen_push($p{name});
			do_gen_code($p{expr});
			&gen_add;
			gen_pop($p{name});
			last;
		};

		/^-=$/ and do {
			gen_push($p{name});
			do_gen_code($p{expr});
			&gen_sub;
			gen_pop($p{name});
			last;
		};

		/^\+\+$/ and do {
			gen_push($p{name});
			gen("add\t\t1");
			gen_pop($p{name});
			last;
		};

		/^--$/ and do {
			gen_push($p{name});
			gen("sub\t\t1");
			gen_pop($p{name});
			last;
		};

		/^!$/ and do {
			do_gen_code($p{expr});
			gen("not");
			last;
		};

		/^RETURN$/ and do {
			print STDERR "> $p{type}\n";

			$p{expr} and do {
				do_gen_code($p{expr});
				gen_pop("#");
			};

			$fcurrent = &alloc_func;
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
			gen("exit");
			$fcurrent = &alloc_func;
			last;
		};

		/^STRING$/ and do {
			$_ = $p{name};
			while (s/^(.)//g) { gen("putc\t" . ord $1) }
			last;
		};
	}
}

sub gen
{
	${$funcs[$fcurrent]}{code} .= "\t" . shift . "\n";
}

sub gen_push
{
	$_ = shift;

	if (/^[0-9]+/) { gen "push\t$_" }
	elsif ($_) {
		my $v = find_var($_);
		$v+1 or die "variable '$_' undefined.\n";
		gen "push\t[$v]";
	}
	else { gen "push" }

	$var_offset++;
}

sub gen_pop
{
	$_ = shift;
	$var_offset--;

	if ($_) {
		my $v = find_var($_);
		$v+1 or die "variable '$_' undefined.\n";
		gen "pop\t[$v]";
	}
	else { gen "pop" }
}

sub gen_add
{
	gen("add");
	$var_offset--;
}

sub gen_sub
{
	gen("sub");
	$var_offset--;
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

sub alloc_func
{
	my %p = (type => undef, name => undef);
	push(@funcs, \%p)-1;
}

sub alloc_param
{
	$_[0] ~~ @param_name and die "parameter '$_[0]' redefined.\n";
	unshift @param_name, shift;
}

sub find_var
{
	my $name = shift;
	my $id;

	$name ~~ @param_name and do {
		($id) = grep { $param_name[$_] eq $name } 0 .. $#param_name;
		return $id + $var_offset + 1;
	};

	($id) = grep { $var_name[$_] eq $name } 0 .. $#param_name;
	defined $id and return $var_offset - $var_id[$id];

	-1;
}

sub alloc_var
{
	find_var($_[0])+1 and die "variable '$_[0]' redefined.\n";
	push @var_name, $_[0];
	push @var_id  , $var_offset;
}


