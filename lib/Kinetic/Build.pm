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

my %CONFIG = (
    pg => {
        version  => '7.4.5',
        store    => 'Kinetic::Store::DB::Pg',
        rules    => 'Kinetic::Build::Rules::Pg',
        dsn      => {
            dbd     => 'Pg',
            db_name => 'db_name',
            methods => {
                host => 'db_host',
                port => 'db_port',
            },
        },
    },
    sqlite => {
        build => 'Kinetic::Build::Store::DB::SQLite',
    },
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

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    # Add elements we need here.
    $self->add_build_element('conf');
    return $self;
}

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

__PACKAGE__->add_property(accept_defaults => 0);

##############################################################################

=head3 store

  my $store = $build->store;
  $build->store($store);

The type of data store to be used for the application. Possible values are
"pg" and "sqlite" Defaults to "sqlite".

=cut

__PACKAGE__->add_property(store => 'sqlite');

##############################################################################

=head3 source_dir

  my $source_dir = $build->source_dir;

The directory where the Kinetic Store libraries will be found.

=cut

__PACKAGE__->add_property(source_dir => 'lib');

##############################################################################

=head3 db_name

  my $db_name = $build->db_name;
  $build->db_name($db_name);

The name of the Kinetic database. Defaults to "kinetic". Not used by the
SQLite data store.

=cut

__PACKAGE__->add_property(db_name => 'kinetic');

##############################################################################

=head3 db_user

  my $db_user = $build->db_user;
  $build->db_user($db_user);

The database user to use to connect to the Kinetic database. Defaults to
"kinetic". Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_user => 'kinetic');

##############################################################################

=head3 db_pass

  my $db_pass = $build->db_pass;
  $build->db_pass($db_pass);

The password for the database user specified by the C<db_user> attribute.
Defaults to "kinetic". Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_pass => 'kinetic');

##############################################################################

=head3 db_root_user

  my $db_root_user = $build->db_root_user;
  $build->db_root_user($db_root_user);

The root or admin database user, which will be used to create the Kinetic
database and user if they don't already exist. The default is the typical root
user name for the seleted data store. Not used by the SQLite data store.

Defaults to postgres.

=cut

__PACKAGE__->add_property(db_root_user => 'postgres');

##############################################################################

=head3 db_root_pass

  my $db_root_pass = $build->db_root_pass;
  $build->db_root_pass($db_root_pass);

The password for the root or admin database user. An empty string by
default. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_root_pass => '');

##############################################################################

=head3 db_host

  my $db_host = $build->db_host;
  $build->db_host($db_host);

The host name of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to localhost via Unix
sockets. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property('db_host');

##############################################################################

=head3 db_port

  my $db_port = $build->db_port;
  $build->db_port($db_port);

The port number of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to the default port for the
database. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property('db_port');

##############################################################################

=head3 conf_file

  my $conf_file = $build->conf_file;
  $build->conf_file($conf_file);

The name of the configuration file. Defaults to F<kinetic.conf>.

=cut

__PACKAGE__->add_property(conf_file => 'kinetic.conf');

##############################################################################

=head3 run_dev_tests

  my $run_dev_tests = $build->run_dev_tests;
  $build->run_dev_tests($run_dev_tests);

Triggers the execution of developer tests. What this means is that, if this
property is set to a true value, a temporary database will be built by the
C<setup_test> action and dropped by the C<teardown_test> action. Tests will
then be run that connect to and make changes to this database. The
C<run_dev_tests> method is set to a false value by default.

=cut

__PACKAGE__->add_property(run_dev_tests => 0);

##############################################################################

=head2 Actions

=head3 check_store

=begin comment

=head3 ACTION_check_store

=end comment

This action checks for the presence of the data store using the C<check_*_>
methods, and prompts for relevant information unless the C<accept_defaults>
attribute has been set to a true value.

=cut

sub ACTION_check_store {
    my $self = shift;
    return $self if $self->notes('build_store');

    # Check the specific store.
    my $build_store_class = $CONFIG{$self->store}{build}
      or $self->_fatal_error("I'm not familiar with the " . $self->store
                             . ' data store');
    eval "use $build_store_class";
    $self->_fatal_error($@) if $@;
    my $build_store = $build_store_class->new($self);
    $build_store->validate;
    $self->notes(build_store => $build_store->serializable);
    $self->notes(build_store_class => $build_store_class);
    return $self;
}

##############################################################################

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
    my $old = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm));
    # Just return if there is no configuration file.
    # XXX Can this burn us?
    return $self unless -e $old;
    my $new = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm.new));
    # Figure out where we're going to install this beast.
    my $base = $self->install_base
      || File::Spec->catdir($self->config->{installprefix}, 'kinetic');
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
    $self->depends_on('check_store');
    $self->depends_on('config');
    $self->SUPER::ACTION_build(@_);
    return $self;
}

##############################################################################

=head3 setup_test

=begin comment

=head3 ACTION_setup_test

=end comment

Sets things up for the test action. For example, if the C<dev_tests> property
has been set to at true value, this action creates the F<t/data> directory for
tests to use as a temporary directory, and sets up a database for testing.

=cut

sub ACTION_setup_test {
    my $self = shift;
    $self->depends_on('check_store');
    $self->depends_on('config');

    # Set up t/data for tests to fill with junk. We'll clean it up.
    my $data = $self->localize_file_path('t/data');
    File::Path::mkpath $data;
    $self->add_to_cleanup($data);

    return $self unless $self->run_dev_tests;

    # Build a test data store.
    my $build_store = $self->notes('build_store');
    $build_store->resume($self);
    $build_store->test_build;
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
    $self->depends_on('setup_test');
    $self->SUPER::ACTION_test(@_);
    $self->depends_on('teardown_test');
}

##############################################################################

=head3 teardown_test

=begin comment

=head3 ACTION_teardown_test

=end comment

Tears down any test infratructure set up during the C<setup_test> action.
This might involve dropping a database, for example.

=cut

sub ACTION_teardown_test {
    my $self = shift;
    # XXX We need a way to say that setup_test needs to run again.
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
    $self->_copy_to($files, $self->blib, 't');

    my %prefix = (
        't/conf/' => 'test_',
        'blib/conf/' => '',
    );

    for my $dir (keys %prefix) {
        my $conf_file = $self->localize_file_path($dir . $self->conf_file);
        open CONF, '<', $conf_file or die "cannot open $conf_file: $!";
        my @conf;
        while (<CONF>) {
            push @conf, $_;
            # Do we have the start of a section?
            next unless /^'?(\w+)'?\s?=>\s?{/;
            # Is there a method for this section?
            my $method = $self->can($prefix{$dir} . $1 . '_config')
              || $self->can($1 . '_config') or next;
            # Dump the default contents of the section.
            while (<CONF>) { last if /^},?$/; }
            if (my @section = $self->$method) {
                # Insert the section contents using the *_config method.
                push @conf, @section, "},\n\n";
            } else {
                # Comment out this section.
                $conf[-1] = "# $conf[-1]";
                push @conf, "# }\n";
            }
            next;
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
#    return "    class => '" . $self->_fetch_store_class . "',\n";
}

##############################################################################

=head3 sqlite_config

This method is called by C<process_conf_files()> to populate the SQLite
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "file" directive.

=cut

sub sqlite_config {
    my $self = shift;
    return unless $self->store eq 'sqlite';
#    return "    file => '" . $self->db_file . "',\n";
}

##############################################################################

=head3 test_sqlite_config

This method is called by C<process_conf_files()> to populate the SQLite
section of the configuration file used for testing. It returns a list of lines
to be included in the section, configuring the "file" directive.

=cut

sub test_sqlite_config {
    my $self = shift;
    return unless $self->store eq 'sqlite';
#    return "    file => '" .
#      $self->localize_file_path('t/store/' . $self->db_file) . "',\n";
}

##############################################################################

=head3 pg_config

This method is called by C<process_conf_files()> to populate the PostgreSQL
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "db_name", "db_user", "db_pass", "host", and
"port" directives.

=cut

sub pg_config {
    my $self = shift;
    return unless $self->store eq 'pg';
    return (
        "    db_name => '" . $self->db_name . "',\n",
        "    db_user => '" . $self->db_user . "',\n",
        "    db_pass => '" . $self->db_pass . "',\n",
        "    host    => " . (defined $self->db_host ? "'" . $self->db_host . "'" : 'undef'), ",\n",
        "    port    => " . (defined $self->db_port ? "'" . $self->db_port . "'" : 'undef'), ",\n",
    );
}

##############################################################################

=head3 test_pg_config

This method is called by C<process_conf_files()> to populate the PostgreSQL
section of the configuration file used during testing. It returns a list of
lines to be included in the section, configuring the "db_name", "db_user", and
"db_pass" directives, which are each set to the temporary value
"__kinetic_test__"; and "host", and "port" directives as specified via the
"db_host" and "db_port" properties.

=cut

sub test_pg_config {
    my $self = shift;
    return unless $self->store eq 'pg';
    return (
        "    db_name => '__kinetic_test__',\n",
        "    db_user => '__kinetic_test__',\n",
        "    db_pass => '__kinetic_test__',\n",
        "    host    => " . (defined $self->db_host ? "'" . $self->db_host . "'" : 'undef'), ",\n",
        "    port    => " . (defined $self->db_port ? "'" . $self->db_port . "'" : 'undef'), ",\n",
    );
}

##############################################################################

=head3 find_conf_files

Called by C<process_conf_files()>, this method returns a hash reference of
configuration file names for processing and copying.

=cut

sub find_conf_files  { shift->_find_files_in_dir('conf') }

##############################################################################

=head3 prompt

This method overrides Module::Build's C<prompt()> method to simply return the
default if the C<accept_defaults> property is set to a true value.

=cut

sub prompt {
    my $self = shift;
    # Let Module::Build do it's thing unless --accept_defaults
    return $self->SUPER::prompt(@_) unless $self->accept_defaults;
    my ($prompt, $default) = @_;
    return $default if $self->quiet;
    # Output the prompt and the value so that they know what's what.
    local $| = 1;
    print "$prompt: ", (defined $default ? $default : '[undefined]'), "\n";
    return $default;
}

##############################################################################

=begin private

=head1 Private Methods

=head2 Class Methods

=head3 _fatal_error

  Kinetic::Build->_fatal_error(@messages)

This method is a standard way of reporting fatal errors.  At the current time,
all we do is croak().

=cut

sub _fatal_error {
    my ($package, @messages) = @_;
    require Carp;
    Carp::croak @messages;
}

##############################################################################

=head2 Instance Methods

=head3 _copy_to

  $build->_copy_to($files, @dirs);

This method copies the files in the C<$files> hash reference to each of the
directories specified in C<@dirs>.

=cut

sub _copy_to {
    my $self = shift;
    my $files = shift;
    return unless %$files;
    while (my ($file, $dest) = each %$files) {
        for my $dir (@_) {
            $self->copy_if_modified(from => $file,
                                    to   => File::Spec->catfile($dir, $dest) );
        }
    }
}

##############################################################################

=head3 _required_version

  $build->_required_version

Returns the minimum required version of the data store.

=cut

sub _required_version {
    my $self = shift;
    return $CONFIG{$self->store}{version};
}

##############################################################################

=head3 _app_info_params

  $build->_app_info_params;

Returns a list of params required for the C<App::Info> object.

=cut

sub _app_info_params {
    my $self = shift;
    my @params = ( on_error => Kinetic::Build::CroakHandler->new($self) );

    unless ($self->quiet) {
        push @params, on_info => Kinetic::Build::PrintHandler->new($self);
    }

    unless ($self->accept_defaults) {
        my $prompter = Kinetic::Build::PromptHandler->new($self);
        push @params,
          on_unknown => $prompter,
          on_confirm => $prompter,
    }
    return @params;
}

##############################################################################

=head3 _rules

  my $rules = $build->_rules;

Debugging hook.  This returns a copy of the Kinetic::Build::Rules object;

=cut

__PACKAGE__->add_property('_rules');

##############################################################################

=head3 _dsn

  my $dsn = $build->_dsn;

This method returns the dsn for the current build

=cut

sub _dsn {
    my $self = shift;
    my $dsn     = $CONFIG{$self->store}{dsn};
    my $db_name_method  = $dsn->{db_name};
    $self->_fatal_error("Cannot create dsn without a db_name")
      unless defined $self->$db_name_method;
    $self->_fatal_error("The database port must be a numeric value")
      if defined $self->db_port and $self->db_port !~ /^[[:digit:]]+$/;
    # the following line is important as the machine rules may override
    # the user's db_name if it doesn't exist.
    my $db_name = $self->notes('db_name') || $self->$db_name_method;
    my $dbd     = "dbi:$dsn->{dbd}:dbname=$db_name";
    my $properties = join ';' =>
        map  { join '=' => @$_ }
        grep { defined $_->[1] }
        map  {
            my $method = $dsn->{methods}{$_};
            [ $_, $self->$method ]
        } sort keys %{ $dsn->{methods} };
    $dbd .= ";$properties" if $properties;
    return $dbd;
}

##############################################################################

=head3 _fetch_store_class

This method is called by C<store_config()>  determine the class that handles a
given store.

=cut

sub _fetch_store_class {
    my $kbsc = $CONFIG{shift->store}{build};
    eval "require $kbsc" or die $@;
    return $kbsc->store_class;
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
    $self->{builder}->log_info($req->message)
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
    $self->{builder}->prompt($req->message, $req->value);
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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
