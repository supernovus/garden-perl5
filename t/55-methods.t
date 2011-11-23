#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>6;

BEGIN { 
  push @INC, './lib';
  push @INC, './t/lib';
}

use Garden;
use TestMethods;

my $garden = Garden->new(paths=>['./t/templates']);
my $methods = TestMethods->new;

my $test = $garden->get('testMethods');
ok ref $test eq 'Garden::Template', 'get() testMethods';

is $test->render(object=>$methods, name=>'bob'), 
   "So, bob in uppercase is BOB\n", 'render() with attribute method calls.';

$test = $garden->get('testMethods/Default');
ok ref $test eq 'Garden::Template', 'get() Default';

my $params = {
  name  => 'Bob',
  title => 'CEO',
};

is $test->render(object=>$methods, params=>$params),
   "The output is: What is this? With Bob, first, CEO\n",
   'render() with a default method call.';

$test = $garden->get('testMethods/Repeat');
ok ref $test eq 'Garden::Template', 'get() testMethods/Repeat';

my $array = [
  'first',
  'second',
  'third',
  'fourth',
  'fifth',
  'sixth',
  'seventh',
];

is $test->render(array=>$array),
   "- first\n- second\n+ third\n+ fourth\n+ fifth\n* sixth\n* seventh\n",
   'render() using Repeat methods that take parameters.';

