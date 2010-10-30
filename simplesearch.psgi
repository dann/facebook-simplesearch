use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use local::lib File::Spec->catdir( dirname(__FILE__), 'extlib' );
use lib File::Spec->catdir( dirname(__FILE__), 'lib' );

use Web::Dispatcher::Simple;
use DBIx::Simple::DataSection;
use Data::Section::Simple qw(get_data_section);
use Text::Xslate;
use Plack::Builder;
use Cwd qw/realpath/;
use File::Basename qw/dirname/;
use Facebook::Graph;
use Config::Pit;
use JSON;

my $BASE_URI;
my $_RENDERER;
my $_FB;

sub api {
    return $_FB if $_FB; 
    my $config = pit_get("facebook.com/simplesearch" , require => {
        "base_uri" => "base_uri",
        "app_id" => "app_id", 
        "secret" => "secret", 
    });
    $BASE_URI = $config->{base_uri};
    $_FB = Facebook::Graph->new(
        postback => $config->{base_uri} . "/postback",
        app_id   => $config->{app_id},
        secret   => $config->{secret},
    );
}

# Renderer
sub renderer {
    return $_RENDERER if $_RENDERER;
    my $vpath = Data::Section::Simple->new()->get_data_section();
    no warnings 'redefine';
    my $renderer = Text::Xslate->new(
        path      => [$vpath],
        syntax    => 'TTerse',
        cache_dir => File::Spec->catfile( root_dir(), ".xslate_cache" ),
        cache     => 1,
    );
    $_RENDERER = $renderer;
    $renderer;
}

sub root_dir {
    my @caller   = caller;
    my $root_dir = dirname( realpath( $caller[1] ) );
    $root_dir;
}

sub redirect {
    my $location = shift;
    return [ 302, [ 'Location' => $location ], [] ];
}

sub not_found {
    return [ 404, [], ['Not found'] ];
}

# Helper
sub render {
    my ( $template_name, $params, $req ) = @_;
    my $res = $req->new_response(200);
    $params ||= {};
    $params->{req} = $req;
    my $body = renderer()->render( $template_name, $params );
    $res->body($body);
    $res;
}

# Logic
sub search_user {
    my $query = shift;
    my $response
        = api()->query->search( $query, 'user' )->limit_results(10)->request;
    my $json_response = eval { $response->as_json; };
    if($@) {
        $json_response = { data => [] };
    } else {
        $json_response = from_json($json_response);
    }
    my $users = $json_response->{data};
    $users;
}

sub authorization_uri {
    api()->authorize->extend_permissions(qw(email offline_access))
                ->uri_as_string;
}

sub get_access_token {
    my $code = shift;
    api()->request_access_token( $code );
    api()->access_token;
}

sub authorized_search_uri {
    my $access_token = shift; 
    my $uri = URI->new($BASE_URI . '/search');
    $uri->query_form( access_token => $access_token );
    $uri->as_string;
}

# Routing
my $app = router {
    get '/' => sub {
        my ( $req, $match ) = @_;
        redirect( authorization_uri() );
    },
    get '/postback' => sub {
        my ( $req, $match ) = @_;
        my $access_token = get_access_token($req->param('code'));
        my $search_uri = authorized_search_uri($access_token);
        redirect( $search_uri );
    },
    get '/search' => sub {
        my ( $req, $match ) = @_;
        my $users = search_user( $req->param('q') );
        render( 'search.tt', { users => $users }, $req );
    }
};

$app = builder {
    enable 'Plack::Middleware::Static',
        path => qr{^/(favicon\.ico$|static/)},
        root => File::Spec->catfile( root_dir(), 'htdocs' );
    $app;
};

return $app;

__DATA__

@@ search.tt
<html>
<body>
<form>
<input type="hidden" name="access_token" value="[% req.param('access_token') %]">
<input type="text" name="q" value="[% req.param('q') %]">
<input type="submit" value="Search">
</form>
<pre>
[%IF req.param('q') %]
[% FOREACH user IN users %]
<div class="user">
User ID: [% user.id %] - Name : [% user.name %]
</div>
[% END %]
[% END %]
</pre>
</body>
</html>

