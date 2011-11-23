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

my $test = $garden->get('pluginsTest');
ok ref $test eq 'Garden::Template', 'get() pluginsTest';

is $test->render(name=>"World"),
   "The plugin says: Hello World\n", 'render() with a plugin loaded.';

