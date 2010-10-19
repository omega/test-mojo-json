use Test::More;
use Test::Mojo::JSON;

use Mojolicious::Lite;
app->log->level('fatal');

get '/json' => sub {
    shift->render(json => {test => 1, test2 => [1,2,3], test3 => {a => 1}});
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
    ->json_query_is('test3', { a  => 1});



done_testing();
