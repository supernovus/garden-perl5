#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('exportTest/Page');
ok ref $test eq 'Garden::Template', 'get() exportTest';

is $test->render(), "Hello World, how are you today?\n", 'render() with imports using exports.';

