use Test::More;
use Test::Mojo::JSON;

use Mojolicious::Lite;
app->log->level('fatal');

get '/json' => sub {
    die "exception";
};
get '/noexception' => sub {
    shift->stash(result => { some => 'json' });
};
any [qw/put/] => '/other' => sub {
    shift->stash(status => 405, result => { error => 'Method not allowed here' } );
};

app->renderer->default_format('json');
app->renderer->default_handler('myjson');
app->renderer->add_handler(
    myjson => sub {
        my ($r, $c, $output, $options) = @_;
        my $js = Mojo::JSON->new;
        if (my $e = $c->stash->{exception}) {
            # uh oh!
            $$output = $js->encode({
                    error => $e->message,
                });
            $c->tx->res->headers->content_type('application/json');
        } else {
            $$output = $js->encode($c->stash->{result}) if $c->stash->{result};
        }
        $$output = '' unless $$output;
    }
);


my $t = Test::Mojo::JSON->new( error => 'error' );

$t->get_ok('/json')->json_exception_is(qr/^exception/);

$t->json_get_ok('/noexception');

$t->put_ok('/other')->is_json->json_exception_is(405 => qr/method not allowed/i);
done_testing();
