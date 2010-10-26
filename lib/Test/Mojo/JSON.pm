package Test::Mojo::JSON;
# ABSTRACT: Helpers for testing JSON responses from Mojo-applications

=head1 SYNOPSIS

    # It takes the place of Test::Mojo
    my $t = Test::Mojo::JSON->new;

=cut

use Mojo::JSON;
use Mojo::URL;

use parent 'Test::Mojo';

__PACKAGE__->attr('error');

=attr error

As an argument to new you can specify a json_query pattern. If you specify this, on
each of json_get_ok, json_put_ok and json_post_ok, we will check to make sure the
response don't match that json_query pattern.

=cut

=method json_get_ok($url)

This behaves like get_ok in L<Test::Mojo>, but checks that the status is 200
and that the response is_json(), using another method in this module

=cut

sub json_get_ok {
    my $self = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->get_ok(@_)->status_is(200)->is_json();
}

=method is_json

Checks that the content_type is 'application/json'

=cut

sub is_json {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    shift->content_type_is('application/json');
}

=method json_query($expression)

Will return parts of a json structure.

The format of $expression is quite simple, it's a string. Each "level" is seperated
by a ".". If a expression-part is a number, it will try to use it as an array, if
the expression-part is a string, it will try to use it as a hash.

Given the following JSON structure (here represented in perl-notation):

     {
        test => 1,
        test2 => [1,2,3],
        test3 => {
            a => 1
        }
    }

We could execute the following queries with the given results

    'test'      =  1
    'test2'     =  [1,2,3]
    'test2.0'   =  1
    'test2.2'   =  3
    'test3'     =  { a => 1 }
    'test3.a'   =  1

=cut

sub json_query {
    my $self = shift;
    my $expr = shift;
    if (!defined($expr)) {
        croak("No expression to query, are you insane?");
    }

    my $ref = $self->json_content;;
    while ($expr ne "") {
        $expr =~ s/(.*?)(?:\.|$)//;
        my $sub = $1;
        if ($sub =~ m/^\d+$/ and ref($ref) eq 'ARRAY') {
            # treat $ref as array
            $ref = $ref->[$sub];
        } elsif ($sub and ref($ref) eq 'HASH') {
            $ref = $ref->{$sub};
        } else {
            return; # Mismatch between query and json struct, so no match
        }
    }
    return $ref;
}

=method json_query_is($expression, [$expected], [$description])

This method lets you check a part of the json structure against some expected value.

The expression is the same as for json_query, so we wont go over that again.

What we do in addition is perform some checking, depending on the type of result
from json_query and the type of $expected.

=for :list

* If both are arrayrefs, we will run is_deeply on the two.
* If result is an arrayref and $expected looks like a number, we check length of
the array against the number
* If both are hashrefs, we will run is_deeply on the two.
* If $expected is a Regexp, we will use Test::More::like on the two
* If $expected is some true value, we will run Test::More::is on the two
* As a fallback we run Test::More::ok on the $result, if we have no $expected value

The description will default to a sane description if you do not provide one.

=cut

sub json_query_is {
    my $self = shift;
    my $expr = shift;
    if (!defined($expr)) {
        croak("No expression to test, are you insane?");
    }
    my $ref = $self->json_query($expr);

    my $expected = shift;
    my $descr = shift || "json query $expr gave us " . ($expected ? $expected : "something");

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    if (ref($ref) eq 'ARRAY' and ref($expected) eq 'ARRAY') {
        Test::More::is_deeply($ref, $expected, $descr);
    } elsif (ref($ref) eq 'ARRAY' and $expected =~ m/^\d+$/) {
        Test::More::is(scalar(@$ref), $expected, $descr);
    } elsif (ref($ref) eq 'HASH' and ref($expected) eq 'HASH') {
        Test::More::is_deeply($ref, $expected, $descr);
    } elsif(ref($expected) eq 'Regexp') {
        Test::More::like($ref, $expected, $descr);
    } elsif($expected) {
        Test::More::is($ref, $expected, $descr);
    } else {
        Test::More::ok($ref, $descr);
    }
    return $self;
}

=method json_content

This is just a shorthand for walking to the json-content via transaction and result

=cut

sub json_content {
    shift->tx->res->json;
}


=method json_post_ok($url, $json_representable_data, [$headers])

Will encode $json_representable_data into a JSON-string, and post that as the body

=cut

sub json_post_ok {
    my $self = shift;
    my $url = shift;
    my $json = shift;
    my $js = Mojo::JSON->new;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->post_ok($url, @_, $js->encode($json));
}

=method json_put_ok($url, $json_representable_data, [$headers])

Will encode $json_representable_data into a JSON-string, and put with the JSON as
the body

=cut

sub json_put_ok {
    my $self = shift;
    my $url = shift;
    my $json = shift;
    my $js = Mojo::JSON->new;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->put_ok($url, @_, $js->encode($json));
}

=method redirect_is($path)

Will check that the path-part of the location-header is $path

=cut

sub redirect_is {
    my $self = shift;
    my $path_is = shift;
    my $desc = shift || 'path part of redirected location is ' . $path_is;
    my $location = Mojo::URL->new( $self->tx->res->headers->location );

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Test::More::is($location->path, $path_is, $desc);
}

=method exception_is($expected, [$descr])

If you set error in the constructor arguments of your Test::Mojo::JSON object,
this method will check that that part of the JSON response is like $expected

=cut

sub exception_is {
    my $self = shift;
    my $expected = shift;
    unless (defined($expected)) {
        croak("No expected value, surely this must be an oversigth on your part?");
    }
    my $descr = shift || 'Our exception matches ' . $expected;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->status_is(500); # we have a 500 error!
    $self->is_json; # and a json response
    $self->json_query_is($self->error, $expected, $descr);
}
1;
