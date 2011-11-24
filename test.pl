## The example from the README, since it should be a test.

use Modern::Perl;

BEGIN {
  push @INC, './lib';
}

use Garden;

my $garden = Garden->new(paths=>['./temp']);
my $test   = $garden->get('testTemplate');

my $data   = {
  name   => "World",
  users  => {
    Bob     => { roles => ['user'],          leader => 0 },
    Kevin   => { roles => ['user','admin'],  leader => 0 },
    Joe     => { roles => ['user','tester'], leader => 1 },
  },
};

say $test->render($data);
