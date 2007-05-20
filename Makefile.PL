use ExtUtils::MakeMaker;

WriteMakefile
(
	'NAME' => 'Data::Visitor',
	'VERSION_FROM' => 'lib/Data/Visitor.pm',
	'PREREQ_PM' => {
		'Class::Accessor'  => '0',
		'Test::MockObject' => '1.04',
		'Test::More'       => '0',
		'Test::use::ok'    => '0'
	},
	'INSTALLDIRS' => 'site',
	'PL_FILES'    => {},
	'SIGN'        => 1,
);
