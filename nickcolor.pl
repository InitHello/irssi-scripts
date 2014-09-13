use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI); 
use YAML qw(LoadFile DumpFile);
use Data::Dumper;

$VERSION = "3";
%IRSSI = (
    authors     => "Timo Sirainen, Ian Peters, David Leadbeater, InitHello",
    contact     => "tss\@iki.fi", 
    name        => "Nick Color",
    description => "assign a different color for each nick",
    license     => "Public Domain",
    url         => "http://irssi.org/",
    changed     => "2014-09-14T11:40-0600"
);

Irssi::theme_register([
    'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
]);

my %saved_colors;
my %session_colors;

my %colors = ();

my %colors = (green => '%g', GREEN => '%G', red => '%r', RED => '%R',
              purple => '%p', PURPLE => '%P', cyan => '%c', CYAN => '%C',
              magenta => '%m', MAGENTA => '%M', yellow => '%y', BLUE => '%B');

# Uncomment the following lines for light backgrounds.

# $colors{black} = '%k';
# $colors{BLACK} = '%K';

sub load_colors {
    my $conf = "$ENV{HOME}/.irssi/colors.yml";
    if (-f $conf) {
        %saved_colors = LoadFile($conf);
    }
}

sub save_colors {
    DumpFile("$ENV{HOME}/.irssi/colors.yml", %saved_colors);
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
    my ($server, $newnick, $nick, $address) = @_;
    my $color;

    $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

    if ($color = $saved_colors{$nick}) {
        $session_colors{$newnick} = $color;
    } 
    elsif ($color = $session_colors{$nick}) {
        $session_colors{$newnick} = $color;
    }
}

# This gave reasonable distribution values when run across
# /usr/share/dict/words

sub simple_hash {
    my $string = shift;
    chomp $string;
    my @chars = split //, $string;
    my $counter;
    my @color_names = keys %colors;

    map { $counter += ord $_ } @chars;
    my $color = $color_names[$counter % $#color_names];
    return $color;
}

sub is_valid {
    my ($nick, $target, $Server) = @_;
    my $chanrec = $Server->channel_find($target);
    return 0 if not $chanrec;
    my $nickrec = $chanrec->nick_find($nick);
    return 0 if not $nickrec;
    my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";
    return 1;
}

sub get_color {
    my ($nick, $address) = @_;
    my $identity = "$nick!$address";

    # Has the user assigned this nick a color?
    my $color = $saved_colors{$nick};

    # Have -we- already assigned this nick a color?
    if (!$color) {
        $color = $session_colors{$nick};
    }

    # Let's assign this nick a color
    if (!$color) {
        $color = simple_hash $identity;
        $session_colors{$nick} = $color;
    }
    return $colors{$color};
}

sub sig_public {
    my ($Server, $msg, $nick, $address, $target) = @_;
    return if not is_valid($nick, $target, $Server);
    my $color = get_color($nick, $address);
    $Server->command(sprintf '/^format pubmsg {pubmsgnick $2 {pubnick %s$0}}$1', $color);
}

sub sig_public_action {
    my ($Server, $msg, $nick, $address, $target) = @_;
    return if not is_valid($nick, $target, $Server);
    my $color = get_color($nick, $address);
    $Server->command(sprintf '/^format action_public {pubaction %s$0}$1', $color);
}

sub cmd_color {
    my ($data, $server, $witem) = @_;
    my ($op, $nick, $color) = split " ", $data;

    $op = lc $op;
    my @validcolors = keys %colors;

    if (!$op) {
        Irssi::print ("No operation given (save/set/clear/list/preview)");
    } 
    elsif ($op eq "save") {
        save_colors;
    } 
    elsif ($op eq "set") {
        if (!$nick) {
            Irssi::print ("Nick not given");
        } 
        elsif (!$color) {
            Irssi::print ("Color not given");
        } 
        elsif (!(grep $_ eq $color, @validcolors)) {
            Irssi::print ("Invalid color. Valid colors are: " . join ', ', map { "$colors{$_}$_%N" } keys %colors);
        } 
        else {
            $saved_colors{$nick} = $color;
        }
    } 
    elsif ($op eq "clear") {
        if (!$nick) {
            Irssi::print ("Nick not given");
        } 
        else {
            delete ($saved_colors{$nick});
        }
    }
    elsif ($op eq "list") {
        Irssi::print ("\nSaved Colors:");
        foreach my $nick (keys %saved_colors) {
            Irssi::print("$colors{$saved_colors{$nick}}$nick%N ($saved_colors{$nick})");
        }
    } 
    elsif ($op eq "preview") {
        Irssi::print ("\nAvailable colors:");
        Irssi::print(join ', ', map { "$colors{$_}$_%N" } keys %colors);
    }
}

if (-f "$ENV{HOME}/.irssi/colors.yml") {
    load_colors;
}

Irssi::command_bind('color', 'cmd_color');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message irc action', 'sig_public_action');
Irssi::signal_add('event nick', 'sig_nick');
Irssi::signal_add('setup saved', 'save_colors');
