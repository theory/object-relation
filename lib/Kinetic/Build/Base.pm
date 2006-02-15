package Kinetic::Build::Base;

# $Id: Build.pm 2630 2006-02-15 05:42:59Z theory $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use 5.008003;
use base 'Module::Build';
use Cwd 'getcwd';
use DBI;
use File::Spec;
use File::Path  ();
use File::Copy  ();
use Config::Std ();
use Scalar::Util 'blessed';
use Term::ANSIColor;

# Be sure to load exceptions early.
use Kinetic::Util::Exceptions;

use version;
our $VERSION = version->new('0.0.1');

my %SETUPS;

=head1 Name

Kinetic::Build::Base - Base class for Kinetic Builders

=head1 Synopsis

In F<Build.PL>:

  use strict;
  use Kinetic::Build::Base;

  my $build = Kinetic::Build::Base->new(
      module_name => 'MyApp',
  );

  $build->create_build_script;

=head1 Description

This module subclasses L<Module::Build|Module::Build> to provide added
functionality for installing Kinetic and Kinetic aplications. It is not
intended to be used directly, but by L<Kinetic::Build|Kinetic::Build> and
L<Kinetic::AppBuild|Kinetic::AppBuild>.

The functionality it adds includes setting a different default value for the
C<install_path> property to "$Config{installprefix}/kinetic", building and
installing the contents of a C<www> directory, and automatically adding the
contents of a C<bin> directory to the C<script_files> property. Read on for
more.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 add_property

  Kinetic::Build::Base->add_property($property);
  Kinetic::Build::Base->add_property($property => $default);
  Kinetic::Build::Base->add_property(%params);

This method overrides the default provided by Module::Build so that properties
can be set up to prompt the user for values as appropriate. In addition to the
support for Module::Build's default arguments--a property name and an optional
default value--this method can take a number of parameters. In such a case, at
least two parameters must be specified (to differentiate from Module::Build's
default syntax).

The supported parameters are the same as those used by C<get_reply()>, but the
C<name>, C<label>, and C<default> parameters are required when passing
parameters rather than using Module::Build's default arguments.

There is also one addional parameter, C<setup>. The C<setup> parameter must be
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
will detect ans set up the appropriate external dependency.

The keys will then be used to populate the C<options> parameter, unless it is
manualy specified. All other parameters will be passed to the C<get_reply()>
method whenever a new Module::Build object is created. Thus, for any such
properties, if they were not set by a command-line parameter, the user will be
prompted for input.

=cut

my @prompts;

sub add_property {
    my $class = shift;
    if ( @_ > 2 ) {

        # This is a property that we may want to prompt for.
        my %params = @_;
        $class->SUPER::add_property(
            $params{name} => delete $params{default}
        );
        if (my $setup = $params{setup}) {
            $SETUPS{$params{name}} = $setup;
            $params{options} ||= [ sort keys %{ $setup } ];
        }
        push @prompts, \%params if keys %params > 1;
    }
    else {

        # This is just a standard Module::Build property.
        $class->SUPER::add_property(@_);
    }
    return $class;
}

##############################################################################

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build::Base->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements
and to run methods that collect data necessary to build the Kinetic framework,
such as data store information.

=cut

sub new {
    my $self = shift->SUPER::new(
        # Set up new default values for parent class properties.
        install_base =>
            File::Spec->catdir( $Config::Config{installprefix}, 'kinetic' ),
        @_    # User-set properties.
    );

    # Prevent installation into lib/perl5. We just want lib'.
    $self->install_path->{lib} ||= $self->install_base . '/lib';

    # Add www element and install path.
    $self->add_build_element('www');
    $self->install_path->{www} ||= $self->install_base . '/www';

    # Prompts.
    for my $prompt (@prompts) {
        my $prop = $prompt->{name};
        $self->$prop( $self->get_reply( %$prompt, default => $self->$prop ) );
        if (my $setup = $SETUPS{$prop}) {
            $self->_check_build_component( $prop, $setup );
        }
    }

    return $self;
}

##############################################################################

=head3 resume

  my $build = Kinetic::Build::Base->resume;

Overrides Module::Build's implementation of the same method in order to set up
the environment so that Kinetic::Util::Config can find the local configuration
file.

=cut

sub resume {
    my $self = shift->SUPER::resume(@_);
    if ( my $conf = $self->notes('build_conf_file') ) {
        $ENV{KINETIC_CONF} ||= $conf;
    }
    while (my ($prop, $class_map) = each %SETUPS) {
        $self->_reload( $prop => $class_map );
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
    name    => 'store',
    label   => 'Data store',
    default => 'sqlite',
    message => 'Which data store back end should I use?',
    setup   => {
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

=head3 schema_skipper

  my $regex = $build->schema_skipper;
  $build->schema_skipper($regex);

Optional property that may be specified as a single regular expression or as
an array reference of regular expressions.
L<Kinetic::Build::Schema|Kinetic::Build::Schema> will match the skipper regex
or regexen against the file name of every Perl module file it finds in the
C<source_dir>. Any file that matches will be not be loaded and will not result
in the buildling of a schema for the module it represents.

Use of this property should not generally be needed unless loading a
non-schema module causes an error during C<./Build>. Such is true of some of
the modules that come with Kinetic itself, for example.

B<Note:> Remember that this regular expression I<will> be used to look at
names on non-Unix file sysems. Design them carefully to anticipate variations
in directory separators and other file system shennanigans. All file names
will be relative to the root of your Kinetic application, e.g.,
F<lib/Foo/Bar.pm> on Unix or F<lib\Foo\Bar.pm> on Windows.

=cut

__PACKAGE__->add_property( schema_skipper => [] );

##############################################################################

=head3 conf_file

  my $conf_file = $build->conf_file;
  $build->conf_file($conf_file);

The name of the configuration file. Defaults to F<kinetic.conf>.

=cut

__PACKAGE__->add_property( conf_file => 'kinetic.conf' );

##############################################################################

=head3 dev_tests

  my $dev_tests = $build->dev_tests;
  $build->dev_tests($dev_tests);

Triggers the execution of developer tests. What this means is that, if this
property is set to a true value, some tests will build temporary databases for
comprehensive testing of all features. Tests will then be run that connect to
and make changes to this database. The C<dev_tests> method is set to a
false value by default.

=cut

__PACKAGE__->add_property( dev_tests => 0 );

##############################################################################

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to add the C<config> action as a
dependency, to set the C<$KINETIC_CONF> environment variable to point to a
tests-specific configuration file, and to set up the C<$KINETIC_SUPPORTED>
environment variable with a space-delimited list of the values of all
properties that specified a C<setup> property, so that tests can detect how
these properties were set.

=cut

sub ACTION_test {
    my $self = shift;
    $self->depends_on('code');
    $self->depends_on('config');

    # Set up the test configuration file.
    local $ENV{KINETIC_CONF} = $self->notes('test_conf_file');

    # Set up a list of supported features.
    # XXX I'm sure we'll add other supported features to this list.
    local $ENV{KINETIC_SUPPORTED} = join ' ', map { $self->$_ } keys %SETUPS
        if $self->dev_tests;

    # Make it so!
    $self->SUPER::ACTION_test(@_);
}

##############################################################################

=head3 help

=begin comment

=head3 ACTION_help

=end comment

Provides help for the user, including a list of all supported command-line
options.

=cut

sub ACTION_help {
    my $self = shift;

    # XXX To be done. The way Module::Build implements this method rather
    # sucks (it expects its own specific POD format), so we'll likely have to
    # hack our own. :-( We'll also want to add something to pull in options
    # specified by the classes referenced in %SETUPS.
    $self->SUPER::ACTION_help(@_);
    return $self;
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
    for my $setup_prop (keys %SETUPS) {
        if (my $setup = $self->notes("build_$setup_prop")) {
            $setup->setup;
        }
    }

    # Create any base objects.
    $self->init_app;

    return $self;
}

##############################################################################

=head2 Methods

=head3 process_conf_files

This method is called during the C<build> action to copy the configuration
files to F<blib/conf> and F<t/conf>. Their contents are also modified to
reflect the contents of the attributes (such as the data store, database
metadata, etc.).

=cut

sub process_conf_files {
    my $self = shift;
    $self->add_to_cleanup('t/conf');
    my $files = $self->find_conf_files;
    return unless %$files;

    for my $conf_file ( $self->_copy_to( $files, $self->blib, 't' ) ) {

        # Load the configuration.
        # XXX https://rt.cpan.org/NoAuth/Bug.html?id=16804
        Config::Std::Hash::read_config( $conf_file => my %conf );

        my $test = '';
        if ( $conf_file =~ /^blib/ ) {
            $self->notes( build_conf_file => $ENV{KINETIC_CONF}
                  = $conf_file );
        }
        else {
            $self->notes( test_conf_file => $conf_file );
            $test = 'test_';

            # KINETIC_ROOT is different for tests than it is for installation
            $conf{kinetic}{root} = getcwd();
        }

        # Configure from setup.
        my $config_meth = "add_to_${test}config";
        for my $setup_prop (keys %SETUPS) {
            if (my $setup = $self->notes("build_$setup_prop")) {
                $setup->$config_meth(\%conf);
            }
        }

        # XXX https://rt.cpan.org/NoAuth/Bug.html?id=16804
        Config::Std::Hash::write_config(%conf);
    }
    return $self;
}

##############################################################################

=head3 process_www_files

This method is called during the C<build> action to copy the Web interfae
files to F<blib/www>.

=cut

sub process_www_files {
    my $self  = shift;
    my $files = $self->find_www_files;
    while (my ($file, $dest) = each %$files) {
        $self->copy_if_modified(
            from => $file,
            to => File::Spec->catfile($self->blib, $dest)
        );
    }
}

##############################################################################

=head3 find_conf_files

Called by C<process_conf_files()>, this method returns a hash reference of
configuration file names for processing and copying.

=cut

sub find_conf_files { shift->find_files_in_dir('conf') }

##############################################################################

=head3 find_script_files

Called by C<process_script_files()>, this method returns a hash reference of
all of the files in the F<bin> directory for processing and copying.

=cut

sub find_script_files { shift->find_files_in_dir('bin') }

##############################################################################

=head3 find_www_files

Called by C<process_www_files()>, this method returns a hash reference of all
of the files in the F<www> directory for processing and copying.

=cut

sub find_www_files { shift->find_files_in_dir('www') }

##############################################################################

=head3 find_files_in_dir

  $build->find_files_in_dir($dir);

Returns a hash reference of of all of the files in a directory, excluding any
with F<.svn> in their paths. Code borrowed from Module::Build's
C<_find_file_by_type()> method.

=cut

sub find_files_in_dir {
    my ( $self, $dir ) = @_;
    return {
        map { $_, $_ }
          map $self->localize_file_path($_),
        @{ $self->rscan_dir( $dir, sub { -f && !/[.]svn/ } ) }
    };
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

The name of the Kinetic::Build::Base property or argument stored in the
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
might pass a code reference like C<sub { /^\d+$/ }>.

=back

=cut

sub get_reply {
    my ( $self, %params ) = @_;
    my $def_label = $params{default};

    my $val = $self->_get_option( $params{name}, $params{callback} );

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
expression of that option wil be returned. If the C<accept_defaults> option
has been specifid or there is no TTY, then the default value will be returned.
Otherwise, C<ask_y_n()> prompts the user, collects an answer, (any value
starting with 'y' or 'n'), and returns the appropriate boolean value.

The supported parameters are the same as for C<get_reply()>, except for the
C<callback> parameter, which is not supported.

=cut

sub ask_y_n {
    my ( $self, %params ) = @_;
    die 'ask_y_n() called without a prompt message' unless $params{label};

    # Return command-line option first.
    my $val = $self->_get_option( $params{name} );
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

This method is called by the C<install> action to add version information for
the current package to the Kinetic data store.

=cut

sub init_app {
    my $self = shift;

    # Set up the version info for this app.
    require Kinetic::VersionInfo;
    Kinetic::VersionInfo->new(
        app_name => $self->module_name,
        version  => version->new( $self->dist_version ),
    )->save;

    return $self;
}

##############################################################################

=head3 fix_shebang_line

  $builder->fix_shegang_line(@files);

This method overrides that in the parent class in order to also process all of
the script files and change any lines containing

  use lib 'lib'

To instead point to the library directory in which the module files will be
installed, e.g., F</usr/local/kinetic/lib>. It then calls the parent method in
order to fix the shebang lines, too.

=cut

sub fix_shebang_line {
    my $self = shift;
    my $lib  = File::Spec->catdir( $self->install_base, 'lib' );

    for my $file (@_) {
        $self->log_verbose(
            qq{Changing "use lib 'lib'" in $file to "use lib '$lib'"} );

        open my $fixin,  '<', $file       or die "Can't process '$file': $!";
        open my $fixout, '>', "$file.new" or die "Can't open '$file.new': $!";
        local $/ = "\n";

        while (<$fixin>) {
            s/use\s+lib\s+'lib'/use lib '$lib'/xms;
            print $fixout $_;
        }

        close $fixin;
        close $fixout;

        rename $file, "$file.bak"
          or die "Can't rename $file to $file.bak: $!";

        rename "$file.new", $file
          or die "Can't rename $file.new to $file: $!";

        unlink "$file.bak"
          or
          $self->log_warn("Couldn't clean up $file.bak, leaving it there\n");
    }

    return $self->SUPER::fix_shebang_line(@_);
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

  Kinetic::Build::Base->fatal_error(@messages)

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

  my $emboldened = Kinetic::Build::Base->_bold_read(@messages);

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
instantiate and instance of it and call its C<validate()> method.

Current supported build components are C<store> and C<engine> and their
respective C<%STORES> and C<%ENGINES> build class hashes.

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

   my $opt = $build->_get_option($key);

Looks in the Module::Build runtime parameters and arguments for an option
specified on the command-line. Options should have dashes between words (such
as "--path-to-sqlite"), and C<_get_options()> will look for a command-line
parameter with dashes and with underscoress. For example, this call:

  my $opt = $build->_get_option('path-to-pg_config');

looks for the option with the equivalent of the following method calls:

  $build->runtime_params('path-to-pg_config');
  $build->runtime_params('path_to_pg_config');
  $build->args('path-to-pg_config');
  $build->args('path_to_pg_config');

=cut

sub _get_option {
    my ( $self, $key, $callback ) = @_;
    return unless defined $key;

    # Allow both dashed and underscored options.
    ( my $alt = $key ) =~ tr/-/_/;
    for my $meth (qw(runtime_params args)) {
        for my $arg ( $key, $alt ) {
            my $val = $self->$meth($arg);
            next unless defined $val;
            return $val unless $callback;
            for (ref $val ? @$val : $val) {
                die qq{"$_" is not a valid value for --$arg}
                    unless $callback->($val);
            }
            return $val;
        }
    }
    return;
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

=head1 See Also

=over

=item L<Kinetic::AppBuild|Kinetic::AppBuild>

The Kinetic application builder and installer.

=back

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
