#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
  use_ok('Garden');
}

my $garden = Garden->new(paths=>['./t/templates']);
ok ref $garden eq 'Garden', 'Garden::new()';

