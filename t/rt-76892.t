use Test::More tests => 2;
use JSON::Schema;

my $schema = {
    type => 'object',
    properties => {
        x => { type => 'integer' },
    },
};

my $doc = {
    foo => 123,
};

my $res = JSON::Schema->new($schema)->validate($doc);
ok($res, "Object with extra property is valid") or diag(join("\n", $res->errors));

$schema->{additionalProperties} = {};
my $res2 = JSON::Schema->new($schema)->validate($doc);
ok($res2, "Same with added empty additionalProperties") or diag(join("\n", $res2->errors));
