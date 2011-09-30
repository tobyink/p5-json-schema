package JSON::Schema;

use 5.008;
use common::sense;

use Carp;
use HTTP::Link::Parser qw[parse_links_to_rdfjson relationship_uri];
use JSON;
use JSON::Hyper;
use JSON::Schema::Error;
use JSON::Schema::Helper;
use JSON::Schema::Result;
use LWP::UserAgent;

our $VERSION = '0.010';

sub new
{
	my ($class, $schema) = @_;
	$schema = from_json($schema) unless ref $schema;
	return bless {schema=>$schema}, $class;
}

sub detect
{
	my ($class, $source) = @_;
	
	my $hyper = JSON::Hyper->new;
	my ($object, $url);
	
	if ($source->isa('HTTP::Response'))
	{
		$url    = $source->request->uri;
		$object = from_json($source->decoded_content);
	}
	else
	{
		$url = "$source";
		($source, my $frag) = split /\#/, $source, 2;
		($object, $source) = $hyper->_get($source);
		$object = fragment_resolve($object, $frag);
	}
	
	# Link: <>; rel="describedby"
	my $links  = parse_links_to_rdfjson($source);
	my @schema =
		map { $class->new( $hyper->get($_->{'value'}) ) }
		grep { lc $_->{'type'} eq 'uri' }
		$links->{$url}->{relationship_uri('describedby')};
	
	# ;profile=
	push @schema,
		map { $class->new( $hyper->get($_) ) }
		map { if (/^\'/) { s/(^\')|(\'$)//g } elsif (/^\"/) { s/(^\")|(\"$)//g } else { $_ } }
		map { s/^profile=// }
		grep /^profile=/,	$source->content_type;
	
	# $schema links
	if ($object)
	{
		push @schema,
			map { $class->new( $hyper->get($_->{'href'}) ) }
			grep { lc $_->{'rel'} eq 'describedby' or lc $_->{'rel'} eq relationship_uri('describedby') }
			$hyper->find_links($object);
	}
	return @schema;
}

sub schema
{
	my ($self) = @_;
	return $self->{'schema'};
}

sub validate
{
	my ($self, $object) = @_;
	$object = from_json($object) unless ref $object;
	
	my $helper = JSON::Schema::Helper->new;
	my $result = $helper->validate($object, $self->schema);
	return JSON::Schema::Result->new($result);
}

sub ua
{
	my $self = shift;	
	$self = {} unless blessed($self);
	
	if (@_)
	{
		my $rv = $self->{'ua'};
		$self->{'ua'} = shift;
		croak "Set UA to something that is not an LWP::UserAgent!"
			unless blessed $self->{'ua'} && $self->{'ua'}->isa('LWP::UserAgent');
		return $rv;
	}
	unless (blessed $self->{'ua'} && $self->{'ua'}->isa('LWP::UserAgent'))
	{
		$self->{'ua'} = LWP::UserAgent->new(agent=>sprintf('%s/%s ', __PACKAGE__, $VERSION));
		$self->{'ua'}->default_header('Accept'=>'application/json, application/schema+json');
	}
	return $self->{'ua'};
}

1;

__END__

=head1 NAME

JSON::Schema - validate JSON against a schema

=head1 SYNOPSIS

 my $validator = JSON::Schema->new($schema);
 my $json      = from_json( ... );
 my $result    = $validator->validate($json);
 
 if ($result)
 {
   print "Valid!\n";
 }
 else
 {
   print "Errors\n";
	print " - $_\n" foreach $result->errors;
 }

=head1 DESCRIPTION

=head2 Constructors

=over 4

=item C<< JSON::Schema->new($schema) >>

Given a JSON (or equivalent Perl nested hashref/arrayref structure)
Schema, returns a Perl object capable of checking objects against
that schema.

Note that some schemas contain '$ref' properties which act as
inclusions; this module does not expand those, but the L<JSON::Hyper>
module can.

=item C<< JSON::Schema->detect($url) >>

Given the URL for a JSON instance (or an HTTP::Response object)
returns a list of schemas (as JSON::Schema objects) that the
JSON instance claims to conform to, detected from the HTTP
response headers.

=back

=head2 Methods

=over 4

=item C<< schema >>

Returns the original schema as a hashref/arrayref structure.

=item C<< validate($object) >>

Validates the object against the schema and returns a
L<JSON::Schema::Result>.

=back

=head2 Perl Specifics

Perl uses weak typing. This module largely gives JSON instances
the benefit of the doubt. For example, if something looks like a
number (e.g. a string which only includes the digits 0 to 9)
then it will validate against schemas that require a number.

The module extends JSON Schema's native set of types ('string',
'number', 'integer', 'boolean', 'array', 'object', 'null', 'any')
with any Perl package name. i.e. the following is valid:

  my $validator = JSON::Schema->new({
    properties => { 
      'time' => { type => ['DateTime','string'] },
	 },
  });
  my $object = {
    'time' => DateTime->now;
  };
  my $result = $schema->validate($object);

This extension makes JSON::Schema useful not just for validating
JSON structures, but acyclic Perl structures generally.

Acyclic. Yes, acyclic. You don't want an infinite loop.

=head1 BUGS

Please report any bugs to L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<JSON::Schema::Result>,
L<JSON::Schema::Error>,
L<JSON::Schema::Helper>,
L<JSON::Schema::Null>,
L<JSON::Schema::Examples>.

Related modules:
L<JSON::T>,
L<JSON::Path>,
L<JSON::GRDDL>,
L<JSON::Hyper>.

L<http://tools.ietf.org/html/draft-zyp-json-schema>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

This is largely a port of Kris Zyp's Javascript JSON Schema validator
L<http://code.google.com/p/jsonschema/>.

=head1 COPYRIGHT AND LICENCE

Copyright 2007-2009 Kris Zyp.

Copyright 2010-2011 Toby Inkster.

This module is tri-licensed. It is available under the X11 (a.k.a. MIT)
licence; you can also redistribute it and/or modify it under the same
terms as Perl itself.

=head2 a.k.a. "The MIT Licence"

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut
