#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>9;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('indirectTest');
ok ref $test eq 'Garden::Template', 'get() indirectTest';

my $hash = {
  one => "First item",
  two => "Second item",
};

my $array = [
  '1st',
  '2nd',
];

is $test->render(hash=>$hash, key=>'one'), 
   "one is First item\n", 'indirect attribute access 1/2.';

is $test->render(hash=>$hash, key=>'two'), 
   "two is Second item\n", 'indirect attribute access 2/2.';

$test = $garden->get('indirectTest/withTemplate');
ok ref $test eq 'Garden::Template', 'get() withTemplate';

is $test->render(template=>'templateOne'),
   "First template\n", 'indirect template calling 1/2.';

is $test->render(template=>'templateTwo'),
   "Second template\n", 'indirect template calling 2/2.';

$test = $garden->get('indirectTest/withApply');
ok ref $test eq 'Garden::Template', 'get() withApply';

is $test->render(array=>$array, template=>'applyOne'),
  "<1st>, <2nd>\n", 'indirect template application 1/2.';

is $test->render(array=>$array, template=>'applyTwo'),
   "(1st), (2nd)\n", 'indirect template application 2/2.';

