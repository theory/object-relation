package TEST::REST::Server;
use base qw(HTTP::Server::Simple::CGI);

use Kinetic::Util::Constants qw/:http/;
use aliased 'Kinetic::UI::REST';

my $REST_SERVER;

my $CACHING = 1;

sub new {
    my ( $class, $value_for ) = @_;
    if ( $value_for->{no_cache} ) {
        $CACHING = 0;
    }
    $REST_SERVER = REST->new( base_url => $value_for->{base_url} );
    $class->SUPER::new( @{ $value_for->{args} } );
}

my $DOC_ROOT      = 'WWW';
my $STATIC        = qr/(js|css)$/;
my %CONTENT_TYPES = (
    js   => 'text/javascript',
    css  => 'text/css',
    xsl  => 'text/xml',
);

my $STATIC_CACHE_FOR;

sub handle_request {
    my ( $self, $cgi ) = @_;
    my $NEWLINE = "\r\n";
    my ( $status, $type, $response );
    $status = OK_STATUS;

    if ( $cgi->path_info =~ $STATIC ) {
        $type = $CONTENT_TYPES{$1};
        my $path = $cgi->path_info;

        if ( !defined( $response = $STATIC_CACHE_FOR{$path} ) ) {
            my $file = $DOC_ROOT . $path;
            local *FH;
            unless ( open FH, '<', $file ) {
                $status   = NOT_FOUND_STATUS;
                $type     = TEXT_CT;
                $response = 'No resource found to handle ' . $path;
            }
            else {
                $response = do { local $/; <FH> };
                if ($CACHING) {
                    $STATIC_CACHE_FOR{$path} = $response;
                }
                close FH;
            }
        }
    }
    else {
        $REST_SERVER->handle_request($cgi);
        $status   = $REST_SERVER->status;
        $type     = $REST_SERVER->content_type;
        $response = $REST_SERVER->response;
    }
    print "HTTP/1.0 $status$NEWLINE";
    print "Content-Type: $type${NEWLINE}Content-Length: ";
    print length($response), $NEWLINE, $NEWLINE, $response;
}

# supress "can connect" printing from HTTP:Server::Simple (grr ...)
sub print_banner { }

1;
