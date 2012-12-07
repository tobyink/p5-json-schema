use strict;
use warnings;
use Test::More;

use JSON::Schema;

my $S = "JSON::Schema"->new(
	{
		type => 'object',
		properties => {
			username => { minLength => 1, maxLength => 64, required => 1 },
			password => { minLength => 6,                  required => 1 },
		},
	},
);

ok     $S->validate({ username => 'abc', password => 'abcdef' });
ok     $S->validate({ username => 'abc', password => 'abcdefgh' });
ok not $S->validate({ username => 'abc', password => 'abcde' });
ok not $S->validate({ username => 'abc' });
ok not $S->validate({ password => 'abcdefgh' });
ok not $S->validate({ username => '', password => 'abcdefgh' });
ok not $S->validate({ username => ('a' x 65), password => 'abcdefgh' });

done_testing;
