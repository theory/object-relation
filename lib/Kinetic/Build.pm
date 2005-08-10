package Kinetic::Build;

# $Id$

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
use DBI;
use File::Spec;
use File::Path ();
use File::Copy ();
# Be sure to load exceptions early.
use Kinetic::Util::Exceptions;

my %STORES = (
    pg     => 'Kinetic::Build::Store::DB::Pg',
    sqlite => 'Kinetic::Build::Store::DB::SQLite',
);

=head1 Name

Kinetic::Build - Kinetic application installer

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
functionality for installing Kinetic and Kinetic applications. The added
functionality includes configuration file management, configuation file setup
for tests, data store schema generation, and database building.

=cut

##############################################################################
# Constructors.
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
default syntax). The parameters will be passed to the C<get_reply()> method
whenever a new Module::Build object is created and the C<accept_defaults>
property is set to a false value (the default). For any such properties,
if they were not set by a command-line parameter, the user will be prompted
for input.

The supported parameters are the same as for the C<get_reply()> method, but
the C<name>, C<lable>, and C<default> parameters are required when passing
parameters rather than using Module::Build's default arguments.

=cut

my @prompts;
sub add_property {
    my $class = shift;
    if (@_ > 2) {
        # This is something we may want to prompt for.
        my %params = @_;
        $class->SUPER::add_property( $params{name} => delete $params{default} );
        push @prompts, \%params if keys %params > 1;
    } else {
        # This is just a standard Module::Build property.
        $class->SUPER::add_property(@_);
    }
    return $class;
}

##############################################################################

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements
and to run methods that collect data necessary to build the Kinetic framework,
such as data store information.

=cut

sub new {
    my $self = shift->SUPER::new(
        # Set up new default values for parent class properties.
        install_base => File::Spec->catdir(
            $Config::Config{installprefix}, 'kinetic'
        ), @_ # User-set properties.
    );

    # Add elements we need here.
    $self->add_build_element('conf');

    # Prompts.
    for my $prompt (@prompts) {
        my $prop = $prompt->{name};
        $self->$prop($self->get_reply(%$prompt, default => $self->$prop));
    }

    $self->check_store;
    return $self;
}

##############################################################################

=head3 resume

  my $build = Kinetic::Build->resume;

Overrides Module::Build's implementation of the same method in order to set up
the environment so that Kinetic::Util::Config can find the local configuration
file.

=cut

sub resume {
    my $self = shift->SUPER::resume(@_);
    if (my $conf = $self->notes('build_conf_file')) {
        $ENV{KINETIC_CONF} = $conf;
    }
    if (my $store = $self->store) {
        my $build_store_class = $STORES{$store}
          or $self->_fatal_error("I'm not familiar with the $store data store");
        eval "require $build_store_class" or $self->_fatal_error($@);
    }
    return $self;
}

##############################################################################

=head3 Class Methods

=head3 test_data_dir

  my $dir = $build->test_data_dir;

Returns the name of a directory that can be used by tests for storing
arbitrary files. The whole directory will be deleted by the C<cleanup>
action. This is a read-only class method.

=cut

use constant test_data_dir => File::Spec->catdir('t', 'data');

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
    options => [ sort keys %STORES ],
    message => 'Which data store back end shold I use?'
);

##############################################################################

=head3 install_base

  my $install_base = $build->install_base;
  $build->install_base($install_base);

Overrides the Module::Build property with this name to put everything under
the "kinetic" directory under the C<Config> module's "installprefix"
directory.

=cut

# Handled in new().

##############################################################################

=head3 source_dir

  my $source_dir = $build->source_dir;

The directory where the Kinetic Store libraries will be found.

=cut

__PACKAGE__->add_property(source_dir => 'lib');

##############################################################################

=head3 conf_file

  my $conf_file = $build->conf_file;
  $build->conf_file($conf_file);

The name of the configuration file. Defaults to F<kinetic.conf>.

=cut

__PACKAGE__->add_property(conf_file => 'kinetic.conf');

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

__PACKAGE__->add_property(dev_tests => 0);

##############################################################################

=head2 Actions

=head3 config

=begin comment

=head3 ACTION_config

=end comment

This action modifies the contents of Kinetic::Util::Config to default to the
location of F<kinetic.conf> specified by the build process. You won't normally
call this action directly, as the C<build> and C<test> actions depend on it.

=cut

sub ACTION_config {
    my $self = shift;
    $self->depends_on('code');

    # Find Kinetic::Util::Config and hard-code the path to the
    # configuration file.
    my @path = qw(lib Kinetic Util Config.pm);
    my $old = File::Spec->catfile($self->blib, @path);
    # Just return if there is no configuration file.
    # XXX Can this burn us?
    return $self unless -e $old;

    # Find Kinetic::Util::Config in lib and just return if it
    # hasn't changed.
    my $lib = File::Spec->catfile(@path);
    return $self if $self->up_to_date($lib, $old);

    # Figure out where we're going to install this beast.
    $path[-1] .= '.new';
    my $new = File::Spec->catfile($self->blib, @path);
    my $base = $self->install_base;
    my $default = '/usr/local/kinetic/conf/kinetic.conf';
    my $config = File::Spec->catfile($base, qw(conf kinetic.conf));

    # Just return if the default is legit.
    return if $base eq $default;

    # Update the file.
    open my $orig, '<', $old or die "Cannot open '$old': $!\n";
    open my $temp, '>', $new or die "Cannot open '$new': $!\n";
    while (<$orig>) {
        s/$default/$config/g;
        print $temp $_;
    }
    close $orig;
    close $temp;

    # Make the switch.
    rename $new, $old or die "Cannot rename '$old' to '$new': $!\n";
    return $self;
}

##############################################################################

=head3 build

=begin comment

=head3 ACTION_build

=end comment

Overrides Module::Build's C<build> action to add the C<config> action as a
dependency.

=cut

sub ACTION_build {
    my $self = shift;
    $self->depends_on('code');
    $self->depends_on('config');
    $self->SUPER::ACTION_build(@_);
    return $self;
}

##############################################################################

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to add the C<config> action as a
dependency.

=cut

sub ACTION_test {
    my $self = shift;
    $self->depends_on('code');
    $self->depends_on('config');

    # Set up t/data for tests to fill with junk. We'll clean it up.
    my $data = $self->test_data_dir;
    File::Path::mkpath $data;
    $self->add_to_cleanup($data);

    # Set up the test configuration file.
    local $ENV{KINETIC_CONF} = $self->notes('test_conf_file');

    # Set up a list of supported features.
    # XXX I'm sure we'll add other supported features to this list.
    local $ENV{KINETIC_SUPPORTED} = join ' ', $self->store
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
    # XXX To be done. The way Module::Build implements this method rathe
    # sucks (it expects its own specific POD format), so we'll likely have to
    # hack our own. :-( We'll also want to add something to pull in options
    # specified by the classes referenced in %STORES.
    $self->SUPER::ACTION_help(@_);
    return $self;
}

##############################################################################

=head2 Methods

=head3 check_store

This method checks for the presence of the data store using the C<check_*_>
methods, and prompts for relevant information unless the C<accept_defaults>
attribute has been set to a true value. Executed by C<new()> (and therefore
the call to C<perl Build.PL>.

=cut

sub check_store {
    my $self = shift;
    return $self if $self->notes('build_store');
    # Check the specific store.
    my $build_store_class = $STORES{$self->store}
      or $self->_fatal_error("I'm not familiar with the " . $self->store
                             . ' data store');
    eval "require $build_store_class" or $self->_fatal_error($@);
    my $build_store = $build_store_class->new($self);
    $build_store->validate;
    $self->notes(build_store => $build_store);
    return $self;
}

##############################################################################

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

    for my $conf_file ($self->_copy_to($files, $self->blib, 't')) {
        my $prefix = '';
        if ($conf_file =~ /^blib/) {
            $self->notes(build_conf_file => $ENV{KINETIC_CONF} = $conf_file);
        } else {
            $self->notes(test_conf_file => $conf_file);
            $prefix = 'test_';
        }
        open CONF, '<', $conf_file or die "cannot open $conf_file: $!";
        my @conf;
        while (<CONF>) {
            push @conf, $_;
            # Do we have the start of a section?
            next unless /^'?(\w+)'?\s?=>\s?{/;
            if ($1 eq $self->store) {
                # It's the configuration section for the data store.
                # Let the store builder set up the configuration.
                my $store = $self->notes('build_store');
                if (my $method = $store->can($prefix . "config")) {
                    if (my $section = $store->$method) {
                        push @conf, $self->_serialize_conf_hash($section),
                          "},\n";
                    }
                }
            } elsif ($STORES{$1}) {
                # It's a section for another data store. Comment it out.
                $conf[-1] = "# $conf[-1]";
                push @conf, "# }\n";
            } elsif (my $method = $self->can($prefix . $1 . '_config')
                     || $self->can($1 . '_config'))
            {
                # There's a configuration method for it in this class.
                if (my $section = $self->$method) {
                    # Insert the section contents using the *_config method.
                    push @conf, $self->_serialize_conf_hash($section), "},\n";
                }
            } else {
                # Continue with the next line to grab the default contents
                # of the section.
                next;
            }

            # Dump the default contents of the section.
            while (<CONF>) { last if /^},?$/; }
        }
        close CONF;
        my $tmp = "$conf_file.tmp";
        open TMP, '>', $tmp or die "cannot open $tmp: $!";
        print TMP @conf;
        close TMP;
        File::Copy::move($tmp, $conf_file);
    }
    return $self;
}

##############################################################################

=head3 store_config

This method is called by C<process_conf_files()> to populate the store
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "class" directive.

=cut

sub store_config {
    my $self = shift;
    my $build_store_class = $STORES{$self->store}
      or $self->_fatal_error("I'm not familiar with the " . $self->store
                             . ' data store');
    eval "require $build_store_class" or $self->_fatal_error($@);
    my $store_class = $build_store_class->store_class;
    return {class => $store_class};
}

##############################################################################

=head3 find_conf_files

Called by C<process_conf_files()>, this method returns a hash reference of
configuration file names for processing and copying.

=cut

sub find_conf_files  { shift->_find_files_in_dir('conf') }

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
C<$_>. For exammple, if you wanted to ensure that a value was an integer, you
might pass a code reference like C<sub { /^\d+$/ }>.

=back

=cut

sub get_reply {
    my ($self, %params) = @_;

    my $def_label = $params{default};
    my $val;
    if (exists $params{name}) {
        $val = $self->runtime_params($params{name});
        $val = $self->args($params{name}) unless defined $val;
    }

    if (defined $val) {
        $params{default} = $val;
    } elsif ($self->_is_tty && ! $self->accept_defaults) {
        if (my $opts = $params{options}) {
            my $i;
            $self->_prompt(join "\n", map({
                $i++;
                $def_label = $i if $_ eq $params{default};
                sprintf "%3s> %-s", $i, $_;
            } @$opts), "");
            $params{callback} = sub { /^\d+$/ && $_ <= @$opts };
        }
        $def_label = defined $def_label ? " [$def_label]:" : '';
        $self->_prompt($params{message}, $def_label, ' ');
      LOOP: {
            my $ans = $self->_readline;
            return $params{default} unless $ans && $ans ne '';
            if (my $code = $params{callback}) {
                local $_ = $ans;
                $self->_prompt("\nInvalid selection, please try again$def_label "),
                  redo LOOP
                  unless $code->($ans);
            }
            return $ans unless $params{options};
            return $params{options}->[$ans-1];
        }
    }

    $def_label = defined $def_label ? " [$def_label]:" : '';
    $self->log_info("$params{label}: $params{default}\n")
      unless $self->quiet;
    return $params{default};
}

##############################################################################

=begin private

=head1 Private Methods

=head2 Class Methods

=head3 _fatal_error

  Kinetic::Build->_fatal_error(@messages)

This method is a standard way of reporting fatal errors. At the current time,
all we do is C<croak()> bold-faced red text.

=cut

sub _fatal_error {
    my $class = shift;
    require Term::ANSIColor;
    if (ref $_[0]) {
        print STDERR Term::ANSIColor::BOLD(), Term::ANSIColor::RED(),
          shift->as_string, Term::ANSIColor::RESET();
        exit 1;
    }
    require Carp;
    Carp::croak Term::ANSIColor::BOLD(), Term::ANSIColor::RED(), @_,
      Term::ANSIColor::RESET();
}

##############################################################################

=head2 Instance Methods

=head3 _copy_to

  my @copied = $build->_copy_to($files, @dirs);

This method copies the files in the C<$files> hash reference to each of the
directories specified in C<@dirs>. Returns a list of the new files.

=cut

sub _copy_to {
    my $self = shift;
    my $files = shift;
    return unless %$files;
    my @ret;
    while (my ($file, $dest) = each %$files) {
        for my $dir (@_) {
            my $file = $self->copy_if_modified(
                from => $file,
                to   => File::Spec->catfile($dir, $dest)
            );
            push @ret, $file if defined $file;
        }
    }
    return @ret;
}

##############################################################################

=head3 _app_info_params

  $build->_app_info_params;

Returns a list of params required for the C<App::Info> object.

=cut

sub _app_info_params {
    my $self = shift;
    my $prompter = Kinetic::Build::PromptHandler->new($self);

    my @params = (
        on_error   => Kinetic::Build::CroakHandler->new($self),
        on_unknown => $prompter,
        on_confirm => $prompter,
    );

    unless ($self->quiet) {
        push @params, on_info => Kinetic::Build::PrintHandler->new($self);
    }

    return @params;
}

##############################################################################

=head3 _find_files_in_dir

  $build->_find_files_in_dir($dir);

Returns a hash reference of of all of the files in a directory, excluding any
with F<.svn> in their paths. Code borrowed from Module::Buld's
C<_find_file_by_type()> method.

=cut

sub _find_files_in_dir {
    my ($self, $dir) = @_;
    return { map {$_, $_}
             map $self->localize_file_path($_),
             @{ $self->rscan_dir($dir, sub { -f && !/\.svn/ }) } };
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
    my $ans = <STDIN>;
    if (defined $ans) {
        chomp $ans;
    } else { # user hit ctrl-D
        $self->_prompt("\n");
    }
    return $ans;
}

##############################################################################

=head3 _serialize_conf_hash

  my @config_lines = $build->_serialize_conf_hash($hashref);

Converts the contents of a hash reference returned by a config method (such as
C<store_config()> or the C<config()> method in Kinetic::Store) to lines
suitable for output to a configuration file.

=cut

sub _serialize_conf_hash {
    my ($self, $conf) = @_;
    map { "    $_ => "
          . (defined $conf->{$_} ? "'$conf->{$_}'" : 'undef') . ",\n"
    } sort keys %$conf;
}

##############################################################################

=head3 _is_tty

  if ($build->_is_tty) { ... }

Returns true if code is being run from a terminal.

=cut

sub _is_tty {
    my $self = shift;
    $self->{tty} = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT))
      unless exists $self->{tty};
    return $self->{tty};
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
    my ($self, $req) = @_;
    $self->{builder}->log_info($req->message);
}

package Kinetic::Build::CroakHandler;
use base 'Kinetic::Build::AppInfoHandler';

sub handler {
    my ($self, $req) = @_;
    $self->{builder}->_fatal_error($req->message);
}

package Kinetic::Build::PromptHandler;
use base 'Kinetic::Build::AppInfoHandler';

sub handler {
    my ($self, $req) = @_;
    $req->value($self->{builder}->get_reply(
        name    => $req->key,
        message => $req->message,
        default => $req->value
    ));
    return $self;
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
