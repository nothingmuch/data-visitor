package Data::Visitor::API::Dispatcher;
use Moose::Role;
use MooseX::Types::Moose qw(ArrayRef HashRef Str CodeRef);

requires (
    'resolve',
);

has [qw(entries isa_entries does_entries)] => (
	isa => HashRef[CodeRef|Str],
	is	=> "ro",
	lazy_build => 1,
);

sub _build_entries { +{} }
sub _build_isa_entries { +{} }
sub _build_does_entries { +{} }

has [qw(all_entries all_isa_entries all_does_entries)] => (
	isa => HashRef,
	is	=> "ro",
	lazy_build => 1,
);

has all_isa_entry_classes => (
	isa => ArrayRef[Str],
	is	=> "ro",
	lazy_build => 1,
);


sub _build_all_entries { shift->entries }
sub _build_all_does_entries { shift->does_entries }
sub _build_all_isa_entries { shift->isa_entries }
sub _build_all_isa_entry_classes {
	my $self = shift;

	return [
		sort { !$a->isa($b) <=> !$b->isa($a) } # least derived first
		keys %{ $self->all_isa_entries }
	];
}

1;
