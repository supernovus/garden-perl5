#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('testImport');
ok ref $test eq 'Garden::Template', 'get() testImport';

is $test->render(), "Hello World, how are you?", 'render() with imports.';

