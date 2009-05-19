use ExtUtils::MakeMaker;

WriteMakefile
(
	'NAME' => 'Data::Visitor',
	'VERSION_FROM' => 'lib/Data/Visitor.pm',
	'PREREQ_PM' => {
		'Any::Moose'       => '0.09',
		'namespace::clean' => '0.08',
		'Test::MockObject' => '1.04',
		'Test::More'       => '0',
		'Test::use::ok'    => '0',
		'Tie::ToObject'    => '0.01',
		#'Data::Alias'      => '0', # deref # FIXME broken on windows
		'Task::Weaken'     => '0',
	},
	'INSTALLDIRS' => 'site',
	'PL_FILES'    => {},
	'SIGN'        => 1,
);
