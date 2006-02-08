#!/usr/bin/perl

package Data::Visitor::Callback;
use base qw/Data::Visitor/;

use strict;
use warnings;

__PACKAGE__->mk_accessors( qw/callbacks ignore_return_values/ );

sub new {
	my ( $class, %callbacks ) = @_;

	my $ignore_ret = 0;
	if	( exists $callbacks{ignore_return_values} ) {
		$ignore_ret = delete $callbacks{ignore_return_values};
	}

	my $self = $class->SUPER::new();

	$self->callbacks( \%callbacks );

	$self;
}

sub visit {
	my ( $self, $data ) = @_;
	local *_ = \$_[1]; # alias $_
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

BEGIN {
	foreach my $reftype ( qw/array hash glob scalar/ ) {
		no strict 'refs';
		*{"visit_$reftype"} = eval '
			sub {
				my ( $self, $data ) = @_;
				my $new_data = $self->callback( '.$reftype.' => $data );
				if ( ref $data eq ref $new_data ) {
					$self->SUPER::visit_'.$reftype.'( $new_data );
				} else {
					$self->SUPER::visit( $new_data );
				}
			}
		' || die $@;
	}
}

sub callback {
	my ( $self, $name, $data ) = @_;

	if ( my $code = $self->callbacks->{$name} ) {
		my $ret = $code->( $self, $data );
		return $self->ignore_return_values ? $data : $ret ;
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

=item new %opts, %callbacks

Construct a new visitor.

The options supported are:

=over 4

=item ignore_return_values

When this is true (off by default) the return values from the callbacks are
ignored, thus disabling the fmapping behavior as documented in
L<Data::Validator>.

This is useful when you want to modify $_ directly

=back

=back

=head1 CALLBACKS

Use these keys for the corresponding callbacks.

The callback is in the form:

	sub {
		my ( $visitor, $data ) = @_;

		# or you can use $_, it's aliased

		return $data; # or modified data
	}

Within the callback $_ is aliased to the data, and this is also passed in the
parameter list.

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

=head1 AUTHOR

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

	Copyright (c) 2006 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut


