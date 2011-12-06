#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

$garden->addGlobal('greeting', 'Hello');

my $test = $garden->get('globalTest');
ok ref $test eq 'Garden::Template', 'get() globalTest';

is $test->render(name=>"World"),
   "Hello World", 'render() with a global variable.';

