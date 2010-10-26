use Test::More;
use Test::Mojo::JSON;

use Mojolicious::Lite;
app->log->level('fatal');

get '/json' => sub {
    die "exception";
};
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

done_testing();
