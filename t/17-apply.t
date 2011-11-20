#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>4;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('apply/expandArray');
ok ref $test eq 'Garden::Template', 'get() expandArray';

my $simple_array = ['one', 'two', 'three'];

is $test->render(array=>$simple_array), "Items: one, two, three\n", 'render() expanding an array with a separator.';

$test = $garden->get('apply/applyArray');
ok ref $test eq 'Garden::Template', 'get() applyArray';

is $test->render(array=>$simple_array), "We have the following items:\n  * one\n  * two\n  * three\n\n", 'render() applying an array.';

