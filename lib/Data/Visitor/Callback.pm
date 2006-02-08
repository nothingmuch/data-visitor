#!/usr/bin/perl

package Data::Visitor::Callback;
use base qw/Data::Visitor/;

use strict;
use warnings;

__PACKAGE__->mk_accessors( "callbacks" );

sub new {
	my ( $class, %callbacks ) = @_;

	my $self = $class->SUPER::new();

	$self->callbacks( \%callbacks );

	$self;
}

sub visit {
	my ( $self, $data ) = @_;
	$self->SUPER::visit( $self->callback( visit => $data ) );
}

sub visit_value {
	my ( $self, $data ) = @_;

	$self->callback( value => $data );
	$self->callback( ( ref($data) ? "ref_value" : "plain_value" ) => $data );
}

sub visit_object {
	my ( $self, $data ) = @_;
	$self->callback( object => $data );
}

sub visit_hash {
	my ( $self, $data ) = @_;
	$self->SUPER::visit_hash( $self->callback( hash => $data ) );
}

sub visit_array {
	my ( $self, $data ) = @_;
	$self->SUPER::visit_array( $self->callback( array => $data ) );
}

sub callback {
	my ( $self, $name, $data ) = @_;

	if ( my $code = $self->callbacks->{$name} ) {
		return $code->( $self, $data );
	} else {
		return $data;
	}
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Data::Visitor::Callback - A Data::Visitor with callbacks.

=head1 SYNOPSIS

	use Data::Visitor::Callback;

	my $v = Data::Visitor::Callback->new(
		value => sub { ... },
		array => sub { ... },
	);

	$v->visit( $some_perl_value );

=head1 DESCRIPTION

This is a L<Data::Visitor> subclass that lets you invoke callbacks instead of
needing to subclass yourself.

=head1 METHODS

=over 4

=item new %callbacks



=back

=head1 CALLBACKS

Use these keys for the corresponding callbacks.

The callback is in the form:

	sub {
		my ( $visitor, $data ) = @_;

		# ...

		return $data; # or modified data
	}

=over 4

=item visit

Called for all values

=item value

Called for non objects, non aggregate (hash, array) values.

=item ref_value

Called after C<value>, for references to regexes, globs and code.

=item plain_value

Called after C<value> for non references.

=item object

Called for blessed objects.

=item array

Called for array references.

=item hash

Called for hash references.

=back

=cut


