#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('jsonTest');
ok ref $test eq 'Garden::Template', 'get() jsonTest';

is $test->render(),
   "Hello World, how are you?\n", 'render() with a JSON block.';

