#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('dictsTest');
ok ref $test eq 'Garden::Template', 'get() dictsTest';

is $test->render(), "Hello world.\nGoodbye universe.\nI am.\n", 'render() using a dictionary.';

