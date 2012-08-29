#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::MockObject::Extends;

use ok "Data::Visitor";

my $v = Data::Visitor->new(
	dispatch_table => Data::Visitor::DispatchTable->new(
		entries => {
			"Some::Class", => sub { $_->{count}++; $_ },
		},
		isa_entries => {
			Bar => sub { $_->{count}++; $_ },
		},
		does_entries => {
            MyRole => sub { $_->{count}++; $_ },
        }
	),
);


{ package Bar };
@Some::Other::Class::ISA = qw(Bar);
{ package MyRole; use Moose::Role; }
{ package RoleConsuming::Class; use Moose; with qw(MyRole); }

my @things = (
    "foo",
    1,
    undef,
    0,
    {},
    [],
    do { my $x = "blah"; \$x },
    my $ref = bless( {}, "Some::Class" ),
    my $isa = bless( {}, "Some::Other::Class" ),
    my $does = RoleConsuming::Class->new,
);

$v->visit($_) for @things; # no explosions in void context

is( $ref->{count},  1, 'Direct Match in entries' );
is( $isa->{count},  1, 'Superclass match' );
is( $does->{count}, 1, 'Role consumption match' );

is_deeply( $v->visit( $_ ), $_, "visit returns value unaltered" ) for @things;

is( $ref->{count},  2, 'Direct Match in entries' );
is( $isa->{count},  2, 'Superclass match' );
is( $does->{count}, 2, 'Role consumption match' );

done_testing;
