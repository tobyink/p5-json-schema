use Test::More tests => 4;
use strict;
use warnings;
use JSON::Schema;

my $schema1 = JSON::Schema->new(
	{
		type => 'object',
		properties => {
			mydate => { format => 'date-time' }
			},
		},
	format => {
		'date-time'  => sub {
			ok(1, 'callback fired');
			$_[0] =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/i;
			}
		});

my $result;

$result = $schema1->validate({mydate => '2011-11-11T11:11:11Z'});
ok $result, 'this should pass'
  or map { diag "reason: $_" } $result->errors;

$result = $schema1->validate({mydate => '2011-11-11T11:11:1Z'});
ok !$result, 'this should fail'
  or map { diag "reason: $_" } $result->errors;
