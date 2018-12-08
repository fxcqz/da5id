unit module Plumber;

my %pending-hooks;
my @hooks;

class Hook is export {
    has Str $.name;
    has Supplier $.supplier;
    has %.taps;
}

sub install-hook(Hook $hook) is export {
    my @matching-hooks = grep {.name eqv $hook.name}, @hooks;
    uninstall-hook($hook.name);
    @hooks.push($hook);
    say @hooks;
}

sub uninstall-hook($name) is export {
    my @matching-hooks = grep {.name eqv $name}, @hooks;
    my @new-hooks = grep {not .name eqv $name}, @hooks;
    # Deactivate existing hook
    for @matching-hooks -> $hook {
        $hook.supplier.done();
    }
    @hooks := @new-hooks;
}

sub install-tap(Tap $tap, $src, $dest) is export {
    my @matching-hooks = grep {.name eqv $src}, @hooks;
    say @matching-hooks;
    if @matching-hooks {
        for @matching-hooks -> $hook {
            if $hook.taps{$dest}:exists {
                $hook.taps{$dest}.close();
            }
            $hook.taps{$dest} = $tap;
        }
        return True;
    } else {
        return False;
    }
}

sub uninstall-tap($src, $dest) is export {
    my @matching-hooks = grep {.name eqv $src}, @hooks;
    for @matching-hooks -> $hook {
        if $hook.taps{$dest}:exists {
            $hook.taps{$dest}:delete
        }
    }
}
