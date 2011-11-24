#!/usr/bin/perl

use warnings;
use strict;

use Module::Build;

Module::Build->new(
    dist_author => "Timothy Totten",
    module_name => 'Garden',
    license => 'artistic_2',
    requires => {
      'Modern::Perl'     => 0,
      'Regexp::Grammars' => 0,
    },
    build_requires => {
      'Test::More'       => 0,
      'Test::Exception'  => 0,
    },
    create_makefile_pl => 'traditional',
)->create_build_script;

