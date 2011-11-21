#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>4;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('testRepeat');
ok ref $test eq 'Garden::Template', 'get() testRepeat';

my $simple_array = ['one', 'two', 'three'];

is $test->render(array=>$simple_array), "---\n  1 one\n  2 two\n  3 three\n\n", 'render() using the repeat object.';

$test = $garden->get('testRepeat/withHash');
ok ref $test eq 'Garden::Template', 'get() withHash';

my $simple_hash = {
  hello   => 'world',
  goodbye => 'universe',
  i       => 'am',
};

is $test->render(hash=>$simple_hash), "---\n  (1) goodbye = universe\n  (2) hello = world\n  (3) i = am\n\n", 'render() using the repeat object on a Hash.';

