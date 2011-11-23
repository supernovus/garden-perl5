#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>2;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('aliasTest');
ok ref $test eq 'Garden::Template', 'get() aliasTest';

my $company = {
  users => {
    bob => {
      name => 'Bob Arnolds',
    },
  },
};

is $test->render(company=>$company, user=>'bob'), 
   "Oh yeah, Bob Arnolds said hi.\n", 'render() an alias.';

