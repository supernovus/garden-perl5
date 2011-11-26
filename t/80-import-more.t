#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
  push @INC, './t/lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('importMore');
ok ref $test eq 'Garden::Template', 'get() importMore';

is $test->render(name=>"World"),
   "Our friend says: Hello World\n", 'render() with imported syntax and plugins.';

