#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests=>7;

BEGIN { 
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./t/templates']);

my $test = $garden->get('basic/hello');
ok ref $test eq 'Garden::Template', 'Garden::get()';

is $test->render(name=>'World'), "Hello World, how are you?", 'render() with single-line template.';

is $test->render(name=>'Bob'), "Hello Bob, how are you?", 'render() with different data, on the same template.';

$test = $garden->get('basic/goodbye');
ok ref $test eq 'Garden::Template', 'another get()';

is $test->render(name=>'Universe'), "  Goodbye Universe, hope to see you again.\n", 'render() with multi-line template.';

$test = $garden->get('testdefault');
ok ref $test eq 'Garden::Template', 'get() on a default namespace template.';

is $test->render(thing=>'Earth'), "Say bye bye to the Earth", 'render() on a default namespace template.';

