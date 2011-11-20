#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>8;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('testSimple');
ok ref $test eq 'Garden::Template', 'Garden::get()';

is $test->render(name=>'World'), "Hello World, how are you?\n", 'render() with nested templates.';

$test = $garden->get('testSimple/passParams');
ok ref $test eq 'Garden::Template', 'nested template';

is $test->render(name=>'Bob', greeting=>"it's good to see you"), "The guy says: \"Hello Bob, it's good to see you\".\n", 'nested templates with passed params.';

$test = $garden->get('testSimple/passNamed');
ok ref $test eq 'Garden::Template', 'nested template 2';

is $test->render(name=>'Kevin', greeting=>"Keep cool man"), "The guy says: \"Yo Kevin! Keep cool man\".\n", 'nested templates with named params.';

$test = $garden->get('testSimple/passNameTemplate');
ok ref $test eq 'Garden::Template', 'nested template 3';

is $test->render(name=>'Alvin'), "The dude says: \"Yo Alvin! It's been a while since I've seen ya Alvin\"!\n", 'nested templates with nested template params.';

