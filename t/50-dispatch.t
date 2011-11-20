#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>3;

BEGIN { 
  push @INC, './lib';
  use_ok('Garden');
}

my $garden = Garden->new(paths=>['./t/templates']);
ok (ref $garden eq 'Garden'), "new() works.";

my $test = $garden->get('dispatch');
ok (ref $test eq 'Garden::Template');

