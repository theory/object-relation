package Kinetic::Build;

# $Id$

use strict;
use 5.008003;
use base 'Module::Build';
use Cwd 'getcwd';
use File::Spec;
use File::Path  ();
use File::Copy  ();
use List::Util 'first';
use Scalar::Util 'blessed';
use Term::ANSIColor;
use Class::ISA;

# Be sure to load exceptions early.
use Kinetic::Store::Exceptions;

use version;
our $VERSION = version->new('0.0.2');

my (%SETUPS_FOR, %PROMPTS_FOR);

=head1 Name

Kinetic::Build - Builds and Installs The Kinetic Platform

=head1 Synopsis

In F<Build.PL>:

  use strict;
  use Kinetic::Build;

  my $build = Kinetic::Build->new(
      module_name => 'MyApp',
  );

  $build->create_build_script;

=head1 Description

This module subclasses L<Module::Build|Module::Build> to provide added
functionality for installing Kinetic and Kinetic applications. It is not
intended to be used directly, but by L<Kinetic::Build|Kinetic::Build>.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 add_property

  Kinetic::Build->add_property($property);
  Kinetic::Build->add_property($property => $default);
  Kinetic::Build->add_property(%params);

This method overrides the default provided by Module::Build so that properties
can be set up to prompt the user for values as appropriate. In addition to the
support for Module::Build's default arguments--a property name and an optional
default value--this method can take a number of parameters. In such a case, at
least two parameters must be specified (to differentiate from Module::Build's
default syntax).

The supported parameters are the same as those used by C<get_reply()>, but the
C<name>, C<label>, and C<default> parameters are required when passing
parameters rather than using Module::Build's default arguments.

There is also one additional parameter, C<setup>. The C<setup> parameter must be
a hash reference wherein the keys are possible values for the property, and
the values are the package names of
L<Kinetic::Build::Setup|Kinetic::Build::Setup> subclasses that perform
detection and setup duties for the option. For example, the C<store> property
has the following C<setup>:

  setup => {
      pg     => 'Kinetic::Build::Setup::Store::DB::Pg',
      sqlite => 'Kinetic::Build::Setup::Store::DB::SQLite',
  }

Depending on the value set for the C<store> property, the corresponding class
will detect and set up the appropriate external dependency.

The keys will then be used to populate the C<options> parameter, unless it is
manually specified. All other parameters will be passed to the C<get_reply()>
method whenever a new Module::Build object is created. Thus, for any such
properties, if they were not set by a command-line parameter, the user will be
prompted for input.

=cut

sub add_property {
    my $class = shift;
    if ( @_ > 2 ) {

        # This is a property that we may want to prompt for.
        my %params = @_;
        $class->SUPER::add_property(
            $params{name} => delete $params{default}
        );
        if (my $setup = $params{setup}) {
            $class->setup_properties unless $SETUPS_FOR{$class};
            $SETUPS_FOR{$class}->{$params{name}} = $setup;
            $params{options} ||= [ sort keys %{ $setup } ];
        }
        push @{ $PROMPTS_FOR{$class} }, \%params if keys %params > 1;
    }
    else {

        # This is just a standard Module::Build property.
        $class->SUPER::add_property(@_);
    }
    return $class;
}

##############################################################################

=head3 test_data_dir

  my $dir = Kinetic::Build->test_data_dir;

Returns the name of a directory that can be used by tests for storing
arbitrary files. The whole directory will be deleted by the C<cleanup>
action. This is a read-only class method.

=cut

use constant test_data_dir => File::Spec->catdir( 't', 'data' );

##############################################################################

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements
and to run methods that collect data necessary to build the Kinetic framework,
such as data store information.

=cut

sub new {
    shift->SUPER::new( @_ )->init;
}

##############################################################################

=head3 resume

  my $build = Kinetic::Build->resume;

Overrides Module::Build's implementation of the same method in order to reload
the setup configuration.

=cut

sub resume {
    my $self = shift->SUPER::resume(@_);
    if (my $setups = $SETUPS_FOR{ref $self}) {
        while (my ($prop, $class_map) = each %{ $setups }) {
            $self->_reload( $prop => $class_map );
        }
    }
    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 Attributes

Module::Build calls these "properties". They can either be specified in
F<Build.PL> by passing them to C<new()>, or they can be specified on the
command line.

=head3 accept_defaults

  my $accept = $build->accept_defaults;
  $build->accept_defaults($accept);

Returns true if all default values for prompts are simply to be accepted, and
false if they are not.

=cut

__PACKAGE__->add_property( accept_defaults => 0 );

##############################################################################

=head3 store

  my $store = $build->store;
  $build->store($store);

The type of data store to be used for the application. Possible values are
"pg" and "sqlite" Defaults to "sqlite".

=cut

__PACKAGE__->add_property(
    name        => 'store',
    label       => 'Data store',
    default     => 'sqlite',
    message     => 'Which data store back end should I use?',
    callback    => sub { s/.*:://; $_ = lc; return 1; },
    setup       => {
        pg     => 'Kinetic::Build::Setup::Store::DB::Pg',
        sqlite => 'Kinetic::Build::Setup::Store::DB::SQLite',
    },
);

##############################################################################

=head3 source_dir

  my $source_dir = $build->source_dir;

The directory where the Kinetic Store libraries will be found.

=cut

__PACKAGE__->add_property( source_dir => 'lib' );

##############################################################################

=head3 dist_version

  my $version = $build->dist_version;

This method overrides that provided by Module::Build to ensure that the
stringified representation of the version number is always used, rather than
the numified version.

Once Module::Build gains full support for version objects, this method can
likely be removed. See
L<http://sourceforge.net/mailarchive/forum.php?thread_id=9761816&forum_id=10905>
for why it's currently necessary.

=cut

sub dist_version {
    local *version::numify = sub { shift };
    return shift->SUPER::dist_version(@_)
}

##############################################################################

=head2 Actions

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to set up the F<t/data> directory for
use by tests. It will be deleted by the C<cleanup> action.

=cut

sub ACTION_test {
    my $self = shift;

    # Set up t/data for tests to fill with junk. We'll clean it up.
    my $data = $self->test_data_dir;
    File::Path::mkpath $data;
    $self->add_to_cleanup($data);

    return $self->SUPER::ACTION_test(@_);
}

##############################################################################

=head3 install

=begin comment

=head3 ACTION_install

=end comment

Overrides Module::Build's C<test> action to call the C<setup> method on all of
the objects created for properties that have specified a C<setup> parameter.
For example, the C<store> property will cause the C<setup> method to be called
on a Kinetic::Build::Setup::Store::SQLite or Kinetic::Build::Setup::Store::Pg
object, thus setting up the database.

=cut

sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install(@_);

    # Set up external dependencies.
    for my $setup ($self->setup_objects) {
        $setup->setup;
    }

    # Create any base objects.
    $self->init_app;

    return $self;
}

##############################################################################

=head2 Methods

=head3 init

 $build->init;

This method is called by C<new()> to initialize the Kinetic::Build
object. It collects data for all properties that have specified a prompt, as
well as their related setup objects, if any.

Essentially, everything that needs to be done before returning a new
Kinetic::Build object is executed here. It is separate from C<new()> so
that subclasses can override it and therefore execute code after the object
has been created but before calling C<SUPER::new()> to execute this code.

=cut

sub init {
    my $self = shift;

    # Prompts.
    for my $class ( reverse Class::ISA::self_and_super_path(ref $self) ) {
        my $prompts = $PROMPTS_FOR{$class} or next;
        for my $prompt (@$prompts) {
            my $prop = $prompt->{name};
            $self->$prop( $self->get_reply( %$prompt, default => $self->$prop ) );
            if (my $setup = $SETUPS_FOR{$class}->{$prop}) {
                $self->_check_build_component( $prop, $setup );
            }
        }
    }

    return $self;
}

##############################################################################

=head3 setup_properties

  my @setup_properties = $build->setup_properites;

Returns a list of "setup properties"--that is, attributes of the class that
were declared by a call to C<add_property()> that included a C<setup>
parameter.

=cut

sub setup_properties {
    my $self = shift;
    my $class = ref $self || $self;
    $SETUPS_FOR{$class} ||= {
        map { $SETUPS_FOR{$_} ? %{ $SETUPS_FOR{$_} } : () }
            Class::ISA::super_path($class)
    };
    return sort keys %{ $SETUPS_FOR{$class} };
}

##############################################################################

=head3 setup_objects

  my @setup_objects = $build->setup_objects;

Returns a list of Kinetic::Build::Setup objects, one for each of the property
names returned by C<setup_properties()>.

=cut

sub setup_objects {
    my $self = shift;
    return $self->notes('build_' . shift) if @_;
    return grep { $_ }
           map  { $self->notes("build_$_") }
           $self->setup_properties;
}

##############################################################################

=head3 get_reply

  my $value = $build->get_reply(%params);

Prompts the user with a message, and then collects a value from the user (if
there is a TTY). A number of options can be specified, and the method will
display a numbered list from which the user to select a value. Callbacks can
also be specified to ensure the quality of a value.

The supported parameters are:

=over

=item message

A message with which to prompt the user, such as "What is your favorite
color?".

=item name

The name of the Kinetic::Build property or argument stored in the
Module::Build C<args()> for which a value is sought. Optional. If the value
was specified on the command-line, the user will not be prompted for a value.

=item label

A label for the value you're attempting to collect, such as "Favorite color".

=item default

A default value. This will be used if the user accepts the value (by hitting)
enter or control-D), and will be returned without prompting the user if the
C<accept_defaults> property is set to a true value or if there is no TTY.

=item options

An array reference of possible values from which the user can select.

=item callback

A code reference that validates a value input by a user. The value to be
checked will be passed in as the first argument and will also be stored in
C<$_>. For example, if you wanted to ensure that a value was an integer, you
might pass a code reference like C<sub { /^\d+$/ }>. Note that if the callback
sets C<$_> to a different value, the revised value is the one that will be
returned. This can be useful for parsing one value from another.

=item environ

The name of an environment variable to check for a value. Checked only after
the Module::Build runtime parameters and arguments have failed to return a
value, but before prompting the user.

=back

=cut

sub get_reply {
    my ( $self, %params ) = @_;
    my $def_label = $params{default};

    # Return command-line and envronment value first.
    my $val = $self->_get_option(
        key         => $params{name},
        callback    => $params{callback},
        environ     => $params{environ},
    );

    if (defined $val) {
        $params{default} = $val;
    }

    elsif ( $self->_is_tty && !$self->accept_defaults ) {
        if ( my $opts = $params{options} ) {
            my $i;
            $self->_prompt(
                join "\n",
                map( {
                    $i++;
                    $def_label = $i if $_ eq $params{default};
                    sprintf "%3s> %-s", $i, $_;
                } @$opts ),
                ""
            );
            $params{callback} = sub { /^\d+$/ && $_ <= @$opts };
        }
        $def_label = defined $def_label ? " [$def_label]:" : '';
        $self->_prompt( $params{message}, $def_label, ' ' );
        LOOP: {
            my $ans = $self->_readline;
            return $params{default} unless $ans && $ans ne '';
            if ( my $code = $params{callback} ) {
                local $_ = $ans;
                unless ($code->($ans)) {
                    $self->_prompt(
                        "\nInvalid selection, please try again",
                        $def_label,
                        ' ',
                    );
                    redo LOOP
                }
            }
            return $ans unless $params{options};
            return $params{options}->[ $ans - 1 ];
        }
    }

    $val = $params{default};
    $self->log_info(
        "$params{label}: ", ( ref $val ? join ', ', @{ $val } : $val ), "\n"
    ) unless $self->quiet;
    return $val;
}

##############################################################################

=head3 ask_y_n

  my $value = $build->ask_y_n(%params);

Use this method to ask the user a yes or no question. It always returns a
boolean value, true for "yes" and false for "no." If an option has been passed
to F<Build.PL> with the same name as the C<name> parameter, then the boolean
expression of that option will be returned. If the C<accept_defaults> option
has been specified or there is no TTY, then the default value will be
returned.  Otherwise, C<ask_y_n()> prompts the user, collects an answer, (any
value starting with 'y' or 'n'), and returns the appropriate boolean value.

The supported parameters are the same as for C<get_reply()>, except for the
C<callback> parameter, which is not supported.

=cut

sub ask_y_n {
    my ( $self, %params ) = @_;
    die 'ask_y_n() called without a prompt message' unless $params{label};

    # Return command-line and envronment value first.
    my $val = $self->_get_option(
        key         => $params{name},
        callback    => sub { $_ = $_ ? 1 : 0; return 1; },
        environ     => $params{environ},
    );

    if (defined $val) {
        $self->log_info("$params{label}: ", ($val ? 'yes' : 'no'), "\n")
            unless $self->quiet;
        return !!$val;
    }

    # Return the default if that's what they want.
    $val = $params{default};
    if ($self->accept_defaults || !$self->_is_tty) {
        $self->log_info("$params{label}: ", ($val ? 'yes' : 'no'), "\n")
            unless $self->quiet;
        return !!$val;
    }

    # Prompt for the answer.
    my $def_label = $params{default} ? ' [y]:' : ' [n]:';
    $self->_prompt( $params{message}, $def_label, ' ' );
    LOOP: {
        $val = $self->_readline;
        return $params{default} unless $val && $val ne '';
        return 1 if $val =~ /^y/i;
        return 0 if $val =~ /^n/i;
        $self->_prompt("Please answer 'y' or 'n'", $def_label, ' ');
        redo LOOP;
    }
}

##############################################################################

=head3 init_app

  $build->init_app;
  $build->init_app($app, $version);

This method is called by the C<install> action to add version information for
the current package to the Kinetic data store. By default it calls
C<module_name()> and C<dist_version()> to get the version numbers, but they
can also be passed in explicitly (for setting up tests, for example).

=cut

sub init_app {
    my ($self, $app, $version) = @_;

    # Make sure that we have a version object.
    $version ||= $self->dist_version;
    $version = version->new($version) unless ref $version;

    return $self;
}

##############################################################################

=head3 log_verbose

  $build->log_verbose(@messages);

Use this method to output messages when the C<verbose> attribute is set to
true. It overrides the parent implementation to change the output of the
messages to boldfaced yellow and to append a newline character if there isn't
one.

=cut

sub log_verbose {
    my $self = shift;
    $self->SUPER::log_verbose(
        Term::ANSIColor::BOLD(),
        Term::ANSIColor::YELLOW(),
        @_,
        ( $_[-1] =~ /\n\Z/ ? '' : "\n" ),
        Term::ANSIColor::RESET(),
    );
}

##############################################################################

=head3 fatal_error

  Kinetic::Build->fatal_error(@messages)

This method is a standard way of reporting fatal errors. At the current time,
all we do is C<croak()> bold-faced red text.

=cut

sub fatal_error {
    my $class = shift;
    if ( blessed( $_[0] ) && $_[0]->can('as_string') ) {
        my $error = shift;
        print STDERR $class->_bold_red( $error->as_string );
        exit 1;
    }
    require Carp;
    Carp::croak $class->_bold_red(@_);
}

##############################################################################

=begin private

=head1 Private Methods

=head2 Private Class Methods

=head3 _bold_red

  my $emboldened = Kinetic::Build->_bold_read(@messages);

Returns @messages surrounded by ANSI terminal codes that will display the
messages in boldfaced red type.

=cut

sub _bold_red {
    my $proto = shift;
    return Term::ANSIColor::BOLD(), Term::ANSIColor::RED(), @_,
      Term::ANSIColor::RESET();
}

##############################################################################

=head2 Private Instance Methods

=head3 _copy_to

  my @copied = $build->_copy_to($files, @dirs);

This method copies the files in the C<$files> hash reference to each of the
directories specified in C<@dirs>. Returns a list of the new files.

=cut

sub _copy_to {
    my $self  = shift;
    my $files = shift;
    return unless %$files;
    my @ret;
    while ( my ( $file, $dest ) = each %$files ) {
        for my $dir (@_) {
            my $file = $self->copy_if_modified(
                from => $file,
                to   => File::Spec->catfile( $dir, $dest )
            );
            push @ret, $file if defined $file;
        }
    }
    return @ret;
}

##############################################################################

=head3 _check_build_component

  $build->_check_build_component($component, \%build_classes);

Given a compent type and hash ref for the current component selected and the
build classes for it, this method attempts to use the correct build class,
instantiate and instance of it and call its C<validate()> method. The
supported build components are those stored in the C<%SETUPS_FOR> hash.

=cut

sub _check_build_component {
    my ( $self, $component, $class_for ) = @_;
    return $self if $self->notes("build_$component");

    # Check the specific component.
    my $build_component_class = $class_for->{ $self->$component }
      or $self->fatal_error(
        "I'm not familiar with the " . $self->$component . " $component"
    );
    eval "require $build_component_class" or $self->fatal_error($@);
    my $build_component = $build_component_class->new($self);
    $build_component->validate;
    $self->notes( "build_$component" => $build_component );
    return $self;
}

##############################################################################

=head3 _app_info_params

  $build->_app_info_params;

Returns a list of params required for the C<App::Info> object.

=cut

sub _app_info_params {
    my $self     = shift;
    my $prompter = Kinetic::Build::PromptHandler->new($self);

    my @params = (
        on_error   => Kinetic::Build::CroakHandler->new($self),
        on_unknown => $prompter,
        on_confirm => $prompter,
    );

    unless ( $self->quiet ) {
        push @params, on_info => Kinetic::Build::PrintHandler->new($self);
    }

    return @params;
}

##############################################################################

=head3 _prompt

  $build->prompt(@messages);

Prompts the user for information with in boldfaced green text (if ANSI colors
are supported).

=cut

sub _prompt {
    my $self = shift;
    require Term::ANSIColor;
    local $| = 1;
    local $\;
    print Term::ANSIColor::BOLD(), Term::ANSIColor::GREEN(), @_,
      Term::ANSIColor::RESET();
    return $self;
}

##############################################################################

=head3 _readline

  my $answer = $build->_readline;

Reads user input from C<STDIN> and returns the (chomped) value. If the user
hits ctrl-D, C<_readline()> passes a newline to a call to C<_prompt()> before
returning the input.

=cut

sub _readline {
    my $self = shift;
    my $ans  = <STDIN>;
    if ( defined $ans ) {
        chomp $ans;
    }
    else {    # user hit ctrl-D
        $self->_prompt("\n");
    }
    return $ans;
}

##############################################################################

=head3 _is_tty

  if ($build->_is_tty) { ... }

Returns true if code is being run from a terminal.

=cut

sub _is_tty {
    my $self = shift;
    $self->{tty} = -t STDIN && ( -t STDOUT || !( -f STDOUT || -c STDOUT ) )
      unless exists $self->{tty};
    return $self->{tty};
}

##############################################################################

=head3 _get_option

   my $opt = $build->_get_option(%params);

Looks in the Module::Build runtime parameters and arguments environment for an
option specified on the command-line. The supported parameters include:

=over

=item key

Required. Identifies the key to use when looking up the option in the
Module::Build runtime parameters and arguments. Options should have dashes
between words (such as "--path-to-httpd"), and C<_get_options()> will look for
a command-line parameter with dashes and with underscoress. For example, this
call:

  my $opt = $build->_get_option(key => 'path-to-httpd');

looks for the option with the equivalent of the following method calls:

  $build->runtime_params('path-to-httpd');
  $build->runtime_params('path_to_httpd');
  $build->args('path-to-httpd');
  $build->args('path_to_httpd');

=item callback

An optional code reference that will be called once a value has been found.
The value will be passed to the callback as its only argument, and also set to
C<$_>. If the callback returns false, C<_get_option()> will throw an
exception.  Note that if the callback sets C<$_> to a different value, the
revised value is the one that will be returned. This can be useful for parsing
one value from another.

=item environ

The name of an environment variable that might contain the value. The
environment is checked only after the Module::Build runtime parameters and
arguments have failed to return a value.

=back

=cut

sub _get_option {
    my ($self, %params) = @_;
    my $key = $params{key};
    return unless defined $key;
    my $callback = $params{callback};

    # Allow both dashed and underscored options.
    ( my $alt = $key ) =~ tr/-/_/;
    for my $meth (qw(runtime_params args)) {
        for my $arg ( $key, $alt ) {
            my $val = $self->$meth($arg);
            next unless defined $val;
            return $val unless $callback;
            return $self->_handle_callback($val, "--$arg", $callback);
        }
    }

    # If we get here, check the environment.
    return unless $params{environ} && defined $ENV{ $params{environ} };
    return $self->_handle_callback(
        $ENV{ $params{environ} },
        qq{the "$params{environ}" environment variable},
        $callback
    );

}

##############################################################################

=head3 _handle_callback

  my $value = $build->_handle_callback($value, $label, $callback);

This method is called by C<_get_option()> to apply a callback to a value. The
value may be an array reference of values, in which case the callback will be
applied to each one. If any calls to the callback return false, an exception
will be thrown, qq{"$value" is not a valid value for $label}.

=cut

sub _handle_callback {
    my ($self, $val, $label, $callback) = @_;
    return $val unless $callback;
    for (ref $val ? @$val : $val) {
        die qq{"$_" is not a valid value for $label}
            unless $callback->($_);
    }
    return $val;
}

##############################################################################

=head3 _reload

   $build->_reload( $key, \%CLASS_MAP );

Called by C<resume()>, this method reloads the appropriate setup class for
Kinetic feature. C<$key> should be the name of the build property that
identifies the feature, such as "store" or "engine". The second argument is a
rference to a hash where the keys identify possible values for the feature
property, and the values are the corresponding subclasses of
L<Kinetic::Build::Setup|Kinetic::Build::Setup> that detect and configure the
feature.

=cut

sub _reload {
    my ( $self, $component, $class_for ) = @_;
    if ( my $component_type = $self->$component ) {
        my $build_class = $class_for->{$component_type}
          or $self->fatal_error(
            "I'm not familiar with the $component_type $component" );
        eval "require $build_class" or $self->fatal_error($@);
    }
    return $self;
}

##############################################################################

package Kinetic::Build::AppInfoHandler;
use base 'App::Info::Handler';

sub new {
    my $self = shift->SUPER::new;
    $self->{builder} = shift;
    return $self;
}

package Kinetic::Build::PrintHandler;
use base 'Kinetic::Build::AppInfoHandler';

sub handler {
    my ( $self, $req ) = @_;
    $self->{builder}->log_info( $req->message, "\n" );
}

package Kinetic::Build::CroakHandler;
use base 'Kinetic::Build::AppInfoHandler';

sub handler {
    my ( $self, $req ) = @_;
    $self->{builder}->fatal_error( $req->message );
}

package Kinetic::Build::PromptHandler;
use base 'Kinetic::Build::AppInfoHandler';

sub handler {
    my ( $self, $req ) = @_;
    ( my $name = lc $req->key ) =~ s/\s+/-/g;
    $req->value(
        $self->{builder}->get_reply(
            name    => $name,
            label   => $req->key,
            message => $req->message,
            default => $req->value
        )
    );
    return $self;
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
