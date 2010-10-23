use Test::More;
use Test::Mojo::JSON;

use Mojolicious::Lite;
app->log->level('fatal');

get '/json' => sub {
    shift->render(json => {test => 1, test2 => [1,2,3], test3 => {a => 1}});
};
post '/json' => sub {
    my $self = shift;
    # Get body somehow
    my $b = $self->tx->req->json;
    $b->{a} = $b->{a} + 1;
    $self->render(json => $b);
};

any [qw/put/] => '/json' => sub {
    my $self = shift;
    my $b = $self->tx->req->json;
    $b->{a} = $b->{a} + 2;
    $self->render(json => $b);
};

get '/redirect' => sub {
    my $self = shift;
    $self->redirect_to('/json');
};

my $t = Test::Mojo::JSON->new;
$t->json_get_ok('/json');

is($t->json_query('test'), 1, "simple json_query works");
is_deeply($t->json_query('test2'), [1,2,3], "returnig an array ref works for json_query");

$t
    ->json_query_is('test')
    ->json_query_is('test', 1)
    ->json_query_is('test2', 3)
    ->json_query_is('test2', [1,2,3])
    ->json_query_is('test2.0', 1)
    ->json_query_is('test3', { a  => 1})
    ->json_query_is('test3.a', 1);


$t->json_post_ok('/json', { a => 2 })
    ->json_query_is('a', 3);

$t->json_put_ok('/json', { a => 4 })->status_is(200)
    ->json_query_is('a', 6);

$t->get_ok('/redirect')->redirect_is('/json');
done_testing();
