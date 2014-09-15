use strict;
use warnings;


use Irssi;
use Irssi::Irc;
use YAML qw(LoadFile DumpFile);

$YAML::Syck::ImplicitUnicode = 1;

my $VERSION = "1.0";
my %IRSSI = (
        authors     => 'InitHello',
        contact     => 'inithello@gmail.com',
        name        => 'slap',
        description => 'mIRC slap, multilingual. Yes, I am horrible.',
        license     => 'BeerWare 2.0 or equivalent',
        url         => 'NA',
);

my %slaps;
my $slapconf = "$ENV{HOME}/.irssi/slaps.yml";

Irssi::command_bind('slap', \&slap);
Irssi::command_bind('addslap', \&addslap);
Irssi::command_bind('listslaps', \&listslaps);
Irssi::signal_add('setup saved', 'saveslaps');
Irssi::signal_add('setup reread', 'loadslaps');

sub slap {
    my ($args, $server, $window) = @_;
    my ($language, $target) = split / /, $args;
    return if !defined $slaps{$language};
    my $slaptext = 'me ' . $slaps{$language};
    $slaptext =~ s/\$1/$target/;
    $window->command($slaptext);
}

sub addslap {
    my $args = shift;
    my ($language, @slap) = split / /, $args;
    $slaps{$language} = join ' ', @slap;
    Irssi::print("Added $language slap as $slaps{$language}");
}

sub saveslaps {
    if (-f $slapconf) {
        DumpFile($slapconf, %slaps);
    }
}

sub listslaps {
    foreach my $language (keys %slaps) {
        Irssi::print(ucfirst $language . ": $slaps{$language}");
    }
}

sub loadslaps {
    if (-f $slapconf) {
        %slaps = LoadFile($slapconf);
    }
}

loadslaps;