use strict;
use Test::More tests => 1;
use JSON::Schema;
use JSON;

ok!(
	JSON::Schema
		-> new({ additionalProperties => JSON::false })
		-> validate({ foo  => "bar" })
);
