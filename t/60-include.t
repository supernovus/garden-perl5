#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('testInclude');
ok ref $test eq 'Garden::Template', 'get() testInclude';

is $test->render(), "Hello World", 'render() with includes.';

