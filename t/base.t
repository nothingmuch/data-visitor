#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 31;
use Test::MockObject::Extends;

my $m;
use ok $m = "Data::Visitor";

can_ok($m, "new");
isa_ok(my $o = $m->new, $m);

can_ok( $o, "visit" );

my @things = ( "foo", 1, undef, 0, {}, [], bless({}, "Some::Class") );

is_deeply( $o->visit( $_ ), $_, "visit returns value unlatered" ) for @things;

can_ok( $o, "visit_value" );
can_ok( $o, "visit_object" );
can_ok( $o, "visit_hash" );
can_ok( $o, "visit_array" );


my $mock = Test::MockObject::Extends->new( $o );

# cause logging
$mock->set_always( $_ => "magic" ) for qw/visit_value visit_object/;
$mock->mock( visit_hash_key => sub { $_[1] } );
$mock->mock( visit_hash => sub { shift->Data::Visitor::visit_hash( @_ )  } );
$mock->mock( visit_array => sub { shift->Data::Visitor::visit_array( @_ )  } );

$mock->clear;
$mock->visit( "foo" );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( 1 );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( undef );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( [ ] );
$mock->called_ok( "visit_array" );
ok( !$mock->called( "visit_value" ), "visit_value not called" );

$mock->clear;
$mock->visit( [ "foo" ] );
$mock->called_ok( "visit_array" );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( "foo" );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( {} );
$mock->called_ok( "visit_hash" );
ok( !$mock->called( "visit_value" ), "visit_value not called" );

$mock->clear;
$mock->visit( { foo => "bar" } );
$mock->called_ok( "visit_hash" );
$mock->called_ok( "visit_value" );

$mock->clear;
$mock->visit( bless {}, "Foo" );
$mock->called_ok( "visit_object" );

is_deeply( $mock->visit( undef ), "magic", "fmap behavior on value" );
is_deeply( $mock->visit( { foo => "bar" } ), { foo => "magic" }, "fmap behavior on hash" );
is_deeply( $mock->visit( [qw/la di da/]), [qw/magic magic magic/], "fmap behavior on array" );

