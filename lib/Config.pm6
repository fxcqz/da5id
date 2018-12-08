unit module Config;

use YAMLish;

my $conf-file-name = "config.yaml";

sub get-config() is export {
    my $config-data = $conf-file-name.IO.slurp;
    return load-yaml($config-data);
}

our %config is export = get-config();

sub update-config() is export {
    spurt($conf-file-name, save-yaml(%config));
}
