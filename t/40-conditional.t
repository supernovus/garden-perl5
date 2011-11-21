#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>12;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('condTest');
ok ref $test eq 'Garden::Template', 'get() condTest';

is $test->render(basic=>1), "Yes\n", 'render() simple conditional, true.';

is $test->render(basic=>0), "No\n",  'render() simple conditional, false.';

$test = $garden->get('condTest/More');
ok ref $test eq 'Garden::Template', 'get() condTest/More';

is $test->render(first=>1, second=>1), 'The first one.', 'conditional chains, 1/4';

is $test->render(first=>1, second=>0), 'The first one.', 'conditional chains, 2/4';

is $test->render(first=>0, second=>1), 'The second one.', 'conditional chains, 3/4';

is $test->render(first=>0, second=>0), 'None of them.', 'conditional chains, 4/4';

$test = $garden->get('condTest/NoDef');

is $test->render(okay=>1), "Q. Is it okay?\nYes\n", 'conditional with no default, true.';

is $test->render(okay=>0), "Q. Is it okay?\n\n", 'conditional with no default, false.';

$test = $garden->get('condTest/Negated');

is $test->render(okay=>1), "No\n", 'negated conditional, true.';

is $test->render(okay=>0), "Yes\n", 'negated conditional, false.';

