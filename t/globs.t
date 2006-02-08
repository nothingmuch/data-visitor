#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::MockObject::Extends;

use ok "Data::Visitor";

our ( $FOO, %FOO );

my $glob = \*FOO;

$FOO = 3;
%FOO = ( foo => "bar" );
is( ${ *$glob{SCALAR} }, 3, "scalar glob created correctly" );
is_deeply( *$glob{HASH}, { foo => "bar" }, "hash glob created correctly" );

my $structure = [ $glob ];

my $mock = Test::MockObject::Extends->new( "Data::Visitor" );
$mock->mock( "visit_$_" => eval 'sub { shift->Data::Visitor::visit_' . $_ . '( @_ )  }' ) for qw/hash glob value array/;

my $mapped = $mock->visit( $structure );

# structure sanity
is( ref $mapped, "ARRAY", "container" );
is( ref ( $mapped->[0] ), "GLOB", "glob ref" );
is( ${ *{$mapped->[0]}{SCALAR} }, 3, "value in glob's scalar slot");

$mock->called_ok( "visit_array" );
$mock->called_ok( "visit_glob" );
$mock->called_ok( "visit_value" );
$mock->called_ok( "visit_hash" );
