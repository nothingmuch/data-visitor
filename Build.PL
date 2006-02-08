#!/usr/bin/perl -w

use strict;

use Module::Build;

Module::Build->new(
	module_name => 'Data::Visitor',
	license => 'perl',
	requires => {
		'perl'	=> '>= 5.008',
	},
	build_requires => {
		'Test::More'                => 0,
		'Test::use::ok'             => 0,
		'Test::MockObject::Extends' => 0,
	},
	create_makefile_pl => 'traditional',
	sign => 1,
)->create_build_script;

